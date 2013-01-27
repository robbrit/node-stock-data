Wat
===

Simple library for extracting stock fundamentals from Google Finance.

Install
=======

Easy:

    npm install stock-data

Usage:
======

Also pretty easy:

    stockData = require("stock-data");

    stockData.fundamentals("NYSEARCA", "SPY", function(err, data){
      console.log(err, data);
    });

Would output (as of Jan. 27, 2013):

    null { price: 150.25,
      range: '149.47 - 150.25',
      range52Week: '130.85 - 150.25',
      open: 149.88,
      volume: 23680000,
      marketCap: 123290000000,
      peRatio: 4.84,
      dividend: 1.02,
      eps: 31.03,
      shares: 820580000,
      beta: 1,
      dividendYield: 2.07,
      averageVolume: '',
      rangeStart: 149.47,
      rangeEnd: 150.25,
      range52WeekStart: 130.85,
      range52WeekEnd: 150.25,
      netProfitMargin: 323.71 }
        
