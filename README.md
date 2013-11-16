# Description

Simple library for extracting stock data fundamentals from Yahoo and Google Finance.

# Installation

    npm install stock-data

# Features

At the moment the feature list is pretty small:

* Fundamental data extraction
* Price extraction by date range

Planned features:

* Dividend Data

# Usage

## Historical Price Data

    stockData = require("stock-data");

    stockData.fetch({
      // this uses Yahoo Finance, so use Yahoo Finance symbols
      symbol: "XIU.TO",
      startDate: "2012-01-01",
      endDate: "2012-12-31"
    }, function (err, data) {
      console.log(data.adj_close);
    });

This data is cached, so subsequent fetches for the same range are not re-fetched
from Yahoo finance. The cached files are stored in `/path/to/stock-data/cache/`.

To skip using the cache:

    stockData.fetch({
      // this uses Yahoo Finance, so use Yahoo Finance symbols
      symbol: "XIU.TO",
      startDate: "2012-01-01",
      endDate: "2012-12-31",
      useCache: false
    }, function (err, data) {
      console.log(data.adj_close);
    });

## Fundamentals

    stockData = require("stock-data");

    // grab fundamental data of SPY - fundamentals uses Google Finance so you
    // need to specify the exchange
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

# Licence

MIT
