# Using the SAS Viya Visual Analytics API to Create Images of Visual Analytics Reports and Report Objects


As of SAS Viya version 2021.2.4, the new [Visual Analytics API](https://developer.sas.com/apis/rest/Visualization/#visual-analytics) makes creating images of SAS Visual Analytics reports easier than ever!   Not only can it be used to create an image file of an entire report tab, but it can also create images of individual report objects.  Using this API, developers can programmatically generate these image files in as little as 10 lines of SAS code!

This directory contains examples of how to use the use the API to create these images of SAS Visual Analytics Report Tabs and Report Objects:

- A SAS program which creates an SVG image file of an entire Visual Analytics Report Tab and saves the file in the private “My Folder” area for the user running the code `createVAFullReportImage.sas`
- A SAS program which creates an SVG image file of a single report object that exists in a Visual Analytics Report and saves the file in the private “My Folder” area for the user running the code - `createVAReportObjectImage.sas`
- A SAS program which creates SVG image files of all graph objects within a Visual Analytics Report, places them into a zip archive named "myZipArchive.zip" and copies final zip file into the Viya files services in the private “My Folder” area for the user running the code - `archiveReportImages.sas`
