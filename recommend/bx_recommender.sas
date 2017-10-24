cas casauto host="host.example.com" port=5570;

libname mycas cas;

/*---------------------------------------------------------------------*/
/* Recommender System                                                  */
/*                                                                     */
/* This example demonstrates the use of many actions within the        */
/* Recommender System (recommend) action set for SAS Cloud Analytic    */
/* Services (CAS). The example uses explicit ratings. The data set is  */
/* the Book-Crossing data set. The data preparation excludes the       */
/* implicit ratings and also excludes ratings that do not match an     */
/* ISBN in the books data set.                                         */
/*                                                                     */
/* You must have access to a SAS Viya 3.3 release of CAS.              */
/*                                                                     */
/* For information about the CAS actions used in this example, see     */
/* Recommender System Action Set: Details in the SAS Visual Analytics  */
/* 8.2: Programming Guide.                                             */
/*                                                                     */
/* Copyright SAS Institute, Inc.                                       */
/*---------------------------------------------------------------------*/

/*-------------------------------------*/
/* Prepare and load data.              */
/*-------------------------------------*/
filename books '/path/to/BX-Books.csv' encoding="wlatin1" lrecl=32767;
data mycas.books(drop='Image'n:);
  infile books firstobs = 2 dsd delimiter = ';';
  /* Read the whole line. */
  input @;
  /* Convert HTML entities (such as &amp;) to single characters. */
  _infile_ = htmldecode(_infile_);
  /* Convert backslash and quotation mark to double quotation marks. */
  _infile_ = tranwrd(_infile_, '\"', '""');

  length tmpisbn $13.;
  length ISBN $10. Title Author Publisher varchar(*);
  length Image_URL_S Image_URL_M Image_URL_L $96.;

  input tmpisbn Title Author Year_Of_Publication
    Publisher $ Image_URL_S $ Image_URL_M $ Image_URL_L $;

  /* Restrict the data to books with a 10 digit ISBN only. */
  if (length(tmpisbn)) ne 10 then delete;
  isbn = tmpisbn;
  drop tmpisbn;
run;

/* Filter the ratings data too. Some ISBNs aren't ISBNs. */
filename ratings '/path/to/BX-Book-Ratings.csv' encoding="wlatin1" lrecl=32767;
/* 1149780 records are read */
data mycas.ratings;
  infile ratings firstobs = 2 dsd delimiter = ';';
  /* Read the whole line. */
  input @;
  /* Remove any line that includes a slash anywhere. */
  if index(_infile_, "/") then delete;

  length tmpisbn $13. ISBN $10.;
  input UserID tmpisbn Rating;

  /* 0 indicates no rating. Remove these for this explicit rating example. */
  if (0 = Rating) then delete;
  if (. = Rating) then delete;

  /* Discard records with invalid ISBNs. */
  if findc(tmpisbn, '0123456789X ', 'V') then delete;

  /* Restrict the data to books with a 10 digit ISBN only. */
  if (length(tmpisbn)) ne 10 then delete;
  isbn = tmpisbn;
  drop tmpisbn;
run;

/* Duplicate ratings for the same item are invalid, so check for them. */
proc cas;
  simple.groupby / table="ratings" inputs={"isbn", "userid"}
    casout={name="dupCheck" replace=1} aggregator="n";

  table.recordCount result = r / 
    table={name="dupCheck" where="_score_ > 1"};
run;
  dupCount = r.RecordCount[1,'N'];
  if 0 = dupCount then
    table.dropTable / table="dupCheck";
  else do;
    print "ERROR: Resolving " || dupCount || " duplicate ratings by using the first rating.";

    dataStep.runCode /
      code="
        data ratingsprep;
          set ratings;
          groupkey = cats('book', isbn, 'user', userid);
        run;
      ";

    dataStep.runCode /
      code="
        data ratings;
          set ratingsprep;
          by groupkey;
          if first.groupkey then output;
          drop groupkey;
        run;
      ";
    table.dropTable / table="ratingsprep";
  end;
run;


/*
 * Remove ratings from the ratings table if the ISBN is not in the books table.
 *
 * This identical to regular DATA step code except that the
 * libref is not included.  In-memory DATA step uses the table
 * name only, like other CAS actions.
 */

proc cas;
  mergePgm = "
    data ratings;
      merge ratings(in=ratings) books(in=books keep=isbn);
      by isbn;
      if books and ratings then output;
    run;";
  dataStep.runCode / code=mergePgm;
run;
  /* Confirm that there are no missing values for ratings. */
  simple.summary /
    table="ratings"
    inputs="rating"
    summarySubset={"mean", "n", "nmiss"};
run;


  table.columnInfo / table="books";
  table.columnInfo / table="ratings";
run;

  table.recordCount / table="books";
  table.recordCount / table="ratings";
run;

/*------------------------------------------------------*/
/* Calculate the sparsity, this is the common challenge */
/* with recommender systems.                            */

/* First, get the number ratings.        */
  table.recordCount result = r / table={name="ratings"};
run;
  /* Store the number of rows in a CASL variable. */
  ratingCount = r.RecordCount[1,'N'];
  
  simple.distinct result = r / table={name="ratings"};

  /* Store the distinct number of users. */
  userCount = r.Distinct.where(Column eq 'UserID')[1,'NDistinct'];

  /* Store the distinct number of items (ISBNs). */
  isbnCount = r.Distinct.where(Column eq 'ISBN  ')[1,'NDistinct'];

  /* Finally, here's the sparsity. */
  sparsity = 1.0 - (ratingCount / (userCount * isbnCount));
  
  /* Create a small table and show it with the results. */
  columns = {"Message", "Sparsity"};
  types   = {"varchar", "double"};
  row     = {"The sparsity of the ratings equals", sparsity};
  SparsityResults = newtable("Sparsity", columns, types, row);
  print SparsityResults;
run;

/* What does the distribution of ratings look like? */
  simple.freq /
    table="ratings"
    inputs="rating"
    raw=True
    casOut={name="ratings_freq" replace=True};
run;
  table.columnInfo / table="ratings_freq";
run;

title1 "Distribution of Ratings";
proc sgplot data=mycas.ratings_freq;
  vbarparm category=_numvar_ response=_frequency_ / barwidth=1;
  label _numvar_='Rating';
  label _frequency_='Frequency';
run;
title1; /* Clear these titles. */
title2;

/*-------------------------------*/
/* Create the recommender system */
/*-------------------------------*/
  /* Create two instances of the ratings table.  One instance  */
  /* is partitioned by userId and the second is partitioned by */
  /* the item.  In this case, the item is the ISBN.            */
proc cas;
  table.partition / 
    table={name="ratings" groupBy="userid"}
    casOut={name="ratings_by_user" replace=True};
  table.partition /
    table={name="ratings" groupBy="isbn"}
    casOut={name="ratings_by_item"};
run;
  table.dropTable / table="ratings";

proc cas;
  recommend.recomCreate /
    system={name="bookRecommend" replace=True} 
    user='userid'
    item='isbn'
    rate='rating';
run;

  /* Specify the ratings table that is partitioned by user. */
  /* If the table is not already partitioned by user, then  */
  /* the action will temporarily group the data for you.    */
  /* However, it slows the action.                          */
  recommend.recomRateInfo result=r /
    table="ratings_by_user"
    label="avg_user_model"
    system="bookRecommend"
    id='userid'
    sparseid='isbn'
    sparseval='rating'
    casOut={name='avg_user', replace=True};
run;

/* table.columnInfo / table="avg_user";
table.fetch / table="avg_user"; */
run;
   recommend.recomRateInfo /
     table="ratings_by_item"
     model="avg_item_model"
     system="bookRecommend"
     id='isbn'
     sparseid='userid'
     sparseval='rating'
     casout={name="avg_item", replace=True};
run;

/* table.columnInfo / table="avg_item";
table.fetch / table="avg_item";run; */


/*------------------------------------------------------*/
 * Are there some of these exploration actions that
 * are better than others?  What would be good to plot?
/*------------------------------------------------------*/

/*
 * Find the discerning reviewers--more than three reviews,
 * and with consistently low ratings.
 */
proc cas;
title1 "Discerning Reviewers";
title2 "More than three reviews and consistently low ratings";
table.fetch /
  table={name="avg_user" where="_nratings_ > 3"}
  sortby="_stat_"
  to=10;
run;

/*
 * Generous reviewers.
 */
title1 "Generous Reviewers";
title2;
table.fetch /
  table={name="avg_user" where="_nratings_ > 3"}
  sortby={
        {name="_stat_" order='DESCENDING'}
        {name="_nratings_" order='DESCENDING'}
  }
  to=10;
run;

/*
 * Frequently reviewed books.
 */
title1 "Ten Most Frequently Reviewed Books";
fedSql.execDirect /
  query='
    select t1.isbn, t1._stat_ as "Average Rating",
    t1._nratings_ as "Number of Ratings",
    t2.author, t2.title from
    avg_item as t1 join books as t2
    on (t1.isbn = t2.isbn) order by 3 desc limit 10';
run;

/*
 * Identify somewhat popular, but less highly rated books.
 */
title1 "Frequently Reviewed Books with Low Ratings";
table.fetch result = r /
  table={name="avg_item" where="_nratings_ > 10"}
  sortby={{name="_stat_"}}
  to=5;

  print r;
run;

  /* Store the ISBN for the first row. */
  firstIsbn = r.Fetch[1,"ISBN"];
  filter = "isbn eq '" || firstIsbn || "'";

call symput('msg', "Rating Distribution for ISBN " || firstIsbn);
run;

title1 &msg.;
  dataPreprocess.histogram result=h /
    table={name="ratings_by_item" where=filter}
    inputs="rating";
run;
  print h['BinDetails'][,{'BinLowerBnd', 'NInBin', 'Percent'}];
run;
/* reset the title */
title1;
 
/*
 * Build a matrix factorization model.
 */
  recommend.recomSample  result =r/
    table="ratings_by_user"
    model="holdout_users"
    hold=1 withhold=0.2 /* From a random selection 20% of users, withold 1 rating. */
    system="bookRecommend"
    seed=1234
    id="userid"
    sparseId="isbn"
    casOut={name="holdout_users" replace=true};
run;


recommend.recomAls result = r /
    tableU="ratings_by_user"
    tableI="ratings_by_item" 
    system="bookRecommend"
    label="als1"
    casOutU={name="als_u" replace=true}
    casOutI={name="als_i" replace=true}
    rateinfo="avg_user"
    maxIter= 20
    hold = "holdout_users" 
    seed = 1234
    details = True
    k=20
    stagnation = 10
    threshold = 0.1 ;
run;
/*
describe r;
run;
*/
  /* Display the tabular results. */
  print r;
run;

  /* Save a SAS data set of the iteration history. */
  saveresult r.IterHistory dataout=work.iterhist;
run;

  /* Plot the optimization of the objective function. */
proc sgplot data=work.iterhist;
  series x=iteration y=objective;
run;


/* Make recommendations for one user. */
proc cas;
  users = {'104437'};

  recommend.recomMfScore /
    system="bookRecommend"
    label='als1'
    userlist=users
    n=5
    casOut={name="recommendations" replace=True};
run;

title1 Recommendations for user 104437;
  fedSql.execDirect /
    query="select t1.*,
      t2.author, t2.title from recommendations
      as t1
      left outer join books as t2 on (t1.isbn = t2.isbn)
      order by userid, _rank_;";
run;


/* Make recommendations for the holdout users. */
  recommend.recomMfScore /
    system="bookRecommend"
    model="als1"
    userTable="holdout_users"
    n=5
    casOut={name="recommend_heldout", replace=True};
run;

  options quotelenmax=0;
  fedSql.execDirect result = r /
    query='select t1.*,
      t2.author, t2.title,
      t3._stat_ as "Average Rating", t3._nratings_ as "Number of Ratings"
      from recommend_heldout as t1
      left outer join books as t2 on (t1.isbn = t2.isbn)
      left outer join avg_item as t3 on (t1.isbn = t3.isbn)
      order by userid, _rank_;';
run;

  firstThreeUsers = r['Result Set'][{1,6,11},{'UserID'}];
  do i = 1 to dim(firstThreeUsers);
    u = firstThreeUsers[i]['UserID'];
    call symput('msg', "Recommendations for user " || u);
    title1 &msg.;
    print r['Result Set'].where(UserID = u);
  end;
run;

title1; /* Reset the title. */

recommend.recomSim /
  table="ratings_by_user"
  label='similar_users' /* Use the userid to partition table, for each user, compute similarity using item as a vector.*/
  system='bookRecommend'
  id ='userid'
  sparseId="isbn"
  sparseVal="rating"
  measure='cos'
  casout={name='similar_users', replace=True}
  threshold=0.2;
run;

proc cas;
function one_users_ratings(u);
  fedSql.execDirect result =r / 
  query='
    select t1.*,
    t2.author, t2.title from ratings_by_user as t1
    left outer join books as t2 on (t1.isbn = t2.isbn)
    where t1.userid = ' || u || '
    order by author, isbn;';
    x.title = "Ratings for user " || u;
    x.table = r;
	return x;
end;

  x = one_users_ratings(104437);
  call symput('msg', x.title);
  title1 &msg.;
  print x.table;
run;

  x = one_users_ratings(199981);
  call symput('msg', x.title);
  title1 &msg.;
  print x.table;
run;

title1;

/*
 * Calculate KNN based on user's similar ratings
 */
recommend.recomKnnTrain /
  table='ratings_by_item'
  label='knn1'
  system='bookRecommend'
  similarity='similar_users'
  k=20
  hold='holdout_users'
  rateinfo='avg_user'
  user=True;
  /* You need to specify if similarity is for the user or the item. */
run;

users = {'104437'};

recommend.recomKnnScore /
  system="bookRecommend"
  model="knn1"
  userList=users
  n=10
  cacheAll=True
  casout={name="knn_recommend" replace=True};
run;

  fedSql.execDirect /
    query='select t1.*,
      t2.author, t2.title,
      t3._stat_ as "Average Rating", t3._nratings_ as "Number of Ratings"
      from knn_recommend as t1
      left outer join books as t2 on (t1.isbn = t2.isbn)
      left outer join avg_item as t3 on (t1.isbn = t3.isbn)
      order by userid, _rank_;
    ';
run;


/*
 * Combine search with recommendations.
 */
table.dropTable / table="book_search" quiet=True;
recommend.recomsearchindex /
  system='bookRecommend'
  table={name='books', vars={'author', 'publisher', 'title'}}
  model='book_search'
  id='isbn';
run;

yoga_query = 'yoga fitness';

recommend.recomSearchQuery /
  system='bookRecommend'
  model='book_search'
  casout={name='query_filter', replace=True}
  query=yoga_query
  n=100;
run;

table.columnInfo / table="query_filter";
run;

yoga_reader = {'99955'};

recommend.recomMfScore /
  system='bookRecommend'
  model='als1'
  filter='query_filter'
  userlist=yoga_reader
  n=5
  casOut={name="filtered_results", replace=True};
run;


  fedSql.execDirect /
    query='select t1.*,
      t2.author, t2.title,
      t3._stat_ as "Average Rating", t3._nratings_ as "Number of Ratings"
      from filtered_results as t1
      left outer join books as t2 on (t1.isbn = t2.isbn)
      left outer join avg_item as t3 on (t1.isbn = t3.isbn)
      order by userid, _rank_;
    ';
run;
quit;





