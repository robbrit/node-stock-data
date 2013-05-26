req = require "request"
jsdom = require "jsdom"
fs = require "fs"
path = require "path"

url = "http://www.google.com/finance?q="

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
