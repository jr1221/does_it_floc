What this extension does when you click it:
-  Shows if the current site is using FLoC
-  Shows if the current site is explicitly blocking FLoC data collection

More info:
W3C is creating a new tracking system, first implemented in Chrome, called the Federated Learning of Cohorts (FLoC).  This new tracking API categorizes people based on their browsing history and gives a cohort ID to a website that requests it.  A cohort could contain a range of people, some could be in the thousands.  Read more here: https://www.theverge.com/2021/3/30/22358287/privacy-ads-google-chrome-floc-cookies-cookiepocalypse-finger-printing

This could replace third party cookies, which will soon be removed in Chrome.

Problems? Open an issue here --> https://github.com/jr1221/does_it_floc/issues

Source code: https://github.com/jr1221/does_it_floc/
Note: Due to CORS issues, there are ways to evade detection of FLoC usage by this extension.

Contributions Welcome!

Building:
`flutter build --web-renderer html --csp`

This project is licensed under the EUPL v1.2