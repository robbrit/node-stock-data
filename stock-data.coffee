req = require "request"
jsdom = require "jsdom"
fs = require "fs"
path = require "path"
_ = require "underscore"
basicCSV = require "basic-csv"

url = "http://www.google.com/finance?q="
CACHE_DIR = "#{__dirname}/cache/"

symbols = {}
jquery = fs.readFileSync(path.resolve(__dirname, "jquery.js")).toString()

# Convert a number like 1.5M to 1 500 000
parseBigNum = (str) ->
  return "" if str is undefined

  if found = str.match /(\d+(\.\d+))K/i
    parseFloat(found[1]) * 1000
  else if found = str.match /(\d+(\.\d+))M/i
    parseFloat(found[1]) * 1000000
  else if found = str.match /(\d+(\.\d+))B/i
    parseFloat(found[1]) * 1000000000
  else if found = str.match /(\d+(\.\d+))T/i
    parseFloat(found[1]) * 1000000000000

# Parse the response from Google Finance
# Fields that it grabs:
# price, range, range52week, open, volume, marketCap, peRatio, dividend,
# eps, shares, beta, netProfitMargin
parseData = (body, onFinish) ->
  jsdom.env(
    html: body
    src: [jquery]
    done: (err, window) ->
      $ = window.$

      mktData = $("#market-data-div")
      data =
        price: parseFloat(mktData.find("#price-panel .pr span").html())
        range: mktData.find(".snap-data td[data-snapfield=\"range\"]")
          .siblings("td").html().trim()
        range52Week: mktData.find(".snap-data td[data-snapfield=\"range_52week\"]")
          .siblings("td").html().trim()
        open: parseFloat(mktData.find(".snap-data td[data-snapfield=\"open\"]")
          .siblings("td").html().trim())
        volume: mktData.find(".snap-data td[data-snapfield=\"vol_and_avg\"]")
          .siblings("td").html().trim()
        marketCap: parseBigNum(mktData.find(".snap-data td[data-snapfield=\"market_cap\"]")
          .siblings("td").html().trim())
        peRatio: parseFloat(mktData.find(".snap-data td[data-snapfield=\"pe_ratio\"]")
          .siblings("td").html().trim())
        dividend: mktData.find(".snap-data td[data-snapfield=\"latest_dividend-dividend_yield\"]")
          .siblings("td").html().trim()
        eps: parseFloat(mktData.find(".snap-data td[data-snapfield=\"eps\"]")
          .siblings("td").html().trim())
        shares: parseBigNum(mktData.find(".snap-data td[data-snapfield=\"shares\"]")
          .siblings("td").html().trim())
        beta: parseFloat(mktData.find(".snap-data td[data-snapfield=\"beta\"]")
          .siblings("td").html().trim())

      # Convert a few fields
      div = data.dividend.split "/"
      data.dividend = parseFloat(div[0])
      data.dividendYield = parseFloat(div[1])

      vol = data.volume.split "/"
      data.volume = parseBigNum(vol[0])
      data.averageVolume = parseBigNum(vol[1])

      range = data.range.split "-"
      data.rangeStart = parseFloat(range[0].trim())
      data.rangeEnd = parseFloat(range[1].trim())

      range52Week = data.range52Week.split "-"
      data.range52WeekStart = parseFloat(range52Week[0].trim())
      data.range52WeekEnd = parseFloat(range52Week[1].trim())

      # Grab some profit related stuff
      sfeSection = $(".sfe-section .quotes")

      sfeSection.find("tr").each ->
        name = $("td.name", this)
        if name.html()?.match /net profit margin/i
          td = $("td.period", this).get(0)
          match = td.innerHTML.match /(\d+\.\d+)%/
          data.netProfitMargin = parseFloat(match[1])

      onFinish data
  )

# Extract some fundamental data from Google Finance.
# Params:
# - mkt : The market to look at (NYSE, NASDAQ, TSE, etc.)
# - sym : The symbol on that market (SPY, MCD, MSFT, etc.)
# - onFinish : a callback to be called when the data returns. Callback takes 2
#              arguments: (error, results), the results object containing
#              various fundamental data.
exports.fundamentals = (mkt, sym, onFinish) ->
  # TODO: support promises
  fullSym = "#{mkt}:#{sym}"

  if symbols[fullSym]
    onFinish null, symbols[fullSym]
  else
    req "#{url}#{fullSym}", (err, resp, body) ->
      if !err and resp.statusCode == 200
        # Got the body
        parseData body, (data) ->
          symbols[fullSym] = data
          onFinish null, symbols[fullSym]
      else
        onFinish err, null

# Fetch price data from Yahoo Finance
exports.fetchPriceData = (options, onFinish) ->
  startDate = options.startDate.split "-"
  endDate = options.endDate.split "-"
  symbol = options.symbol

  url = "http://ichart.finance.yahoo.com/table.csv?" +
    [
      "s=#{symbol}"
      "d=#{parseInt(endDate[1], 10) - 1}"
      "e=#{parseInt endDate[2], 10}"
      "f=#{endDate[0]}"
      "g=d" # this is for daily quotes
      "a=#{parseInt(startDate[1], 10) - 1}"
      "b=#{parseInt startDate[2], 10}"
      "c=#{startDate[0]}"
      "ignore=.csv"
    ].join("&")

  req url, (err, resp, body) ->
    onFinish err, body

# Parse Yahoo Finance CSV data into an object like this:
#   {
#     date: [...],
#     open: [...],
#     close: [...],
#     ...
#   }
parseCSVData = (csvData, onFinish) ->
  basicCSV.readCSVFromString csvData, {
    dropHeader: true
  }, (err, rows) ->
    if err
      onFinish err, null
      return

    fields = ["date", "open", "high", "low", "close", "volume", "adj_close"]
    frame = {}

    _.each fields, (fieldName, i) ->
      frame[fieldName] = []

    _.each rows, (row, i) ->
      _.each fields, (fieldName, j) ->
        # Use unshift to reverse the array
        frame[fieldName].unshift(row[j])

    onFinish null, frame

# Extract historical price data from Yahoo Finance - using Yahoo Finance since
# Google Finance does not support historical data for Canada.
# Possible options:
exports.fetch = (options, onFinish) ->
  options = _.defaults options, {
    useCache: true
    startDate: "2012-01-01"
    endDate: "2012-12-31"
  }

  # Check if it is available in the cache
  fileName = [options.symbol, options.startDate, options.endDate].join "-"
  fileName = "#{CACHE_DIR}#{fileName}.csv"

  if options.useCache
    fs.exists fileName, (exists) ->
      if exists
        fs.readFile fileName, "utf-8", (err, data) ->
          if err
            onFinish err, null
          else
            parseCSVData data, onFinish
      else
        exports.fetchPriceData options, (err, data) ->
          if err
            onFinish err, null
            return

          fs.mkdir CACHE_DIR, (err) ->
            if err
              onFinish err
              return

            fs.writeFile fileName, data, (err) ->
              if err
                onFinish err
              else
                parseCSVData data, onFinish
  else
    exports.fetchPriceData options, (err, data) ->
      if err
        onFinish err, null
      else
        parseCSVData data, onFinish

