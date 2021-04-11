#dateFormatSpecifier = '%m/%d/%Y'
#dateFormat = d3.timeFormat(dateFormatSpecifier)
#dateFormatParser = d3.timeParse(dateFormatSpecifier)
dateFormat = d3.isoFormat
dateDisplayFormat = d3.timeFormat("%d.%m.%Y %H:%M:%S")
dateOnlyDisplayFormat = d3.timeFormat("%d.%m.%Y")
dateFormatParser = d3.isoParse
numberFormat = d3.format('.1f')

dc.config.defaultColors(d3.schemeTableau10)
d3.csv("posts.csv").then (data) ->
	data.forEach (d) ->
		d.dd = dateFormatParser d.date
		d.week = d3.timeWeek(d.dd)
		d.reactions = +d.reactions
		d.comments = +d.comments
	
	start_date = new Date 2015, 1, 1
	data = data.filter (d) ->
		d.dd > start_date
	
	ndx = crossfilter(data)
	
	timeDimension = ndx.dimension (d) -> d.dd
	weekDimension = ndx.dimension (d) -> d.week
	pubtypeDimension = ndx.dimension (d) ->
		if not d.link
			if d.share_id
				return "Jako"
			return "Teksti tai kuva"
		{
			"story": "Juttu",
			"press_release": "Tiedote",
			"article": "Akateeminen"
		}[d.publication] ? "Luokaton linkki"

	publisherDimension = ndx.dimension (d) ->
		return "Linkitön" if not d.link
		{
			"private": "Yritys",
			"journal": "Tiedejulkaisu"
			"university": "Yliopisto"
			"go": "Julkinen"
			"ngo": "Järjestö"
			"personal": "Henkilökohtainen"
		}[d.institution] ? "Luokaton"

	interestDimension = ndx.dimension (d) ->
		return "Linkitön" if not d.link
		{
			"public": "Julkinen"
			"political": "Poliittinen"
			"business": "Elinkeinoelämä"
			"labour": "Ammattiyhdistys"
			"special": "Erityinen"
		}[d.interest] ? "Luokaton"

	
	postsPerDay = weekDimension.group().reduceSum((d) -> 1/7)
	averager = (f) -> [
		(p, v) ->
			p.total += f(v); p.count += 1; p.average = p.total/p.count
			return p
		(p, v) ->
			p.total -= f(v); p.count -= 1
			if p.count == 0
				p.average = 0
			else
				p.average = p.total/p.count
			return p
		() -> total: 0, count: 0, average: 0
		]
	likesPerPost = weekDimension.group().reduce averager((d) -> d.reactions)...
	commentsPerPost = weekDimension.group().reduce averager((d) -> d.comments)...
	
	total_posts = ndx.size()
	total_selected = ndx.groupAll()
	likesPerPostTotal = ndx.groupAll().reduce averager((d) -> d.reactions)...
	commentsPerPostTotal = ndx.groupAll().reduce averager((d) -> d.comments)...
	
	time_extent = d3.extent data, (d) -> d.dd
	height = 250
	transdur = 1000
	tablelimit = 100
	
	window.timechart = dc.compositeChart("#timeseries-chart")
	timeinfo = document.getElementById("timeseries-info")
	actinfo = document.getElementById("activity-info")
	tablecounts = document.getElementById("table-counts")
	_MS_PER_DAY = 1000 * 60 * 60 * 24
	update_timeinfo = ->
		timefilt = timechart.filter()
		if not timefilt
			[s, e] = time_extent
		else
			[s, e] = timefilt
		dur = (e - s)/_MS_PER_DAY

		selected = total_selected.value()
		timeinfo.innerHTML = """
			<strong>Tarkasteluväli #{Math.floor dur}</strong> päivää
			(#{dateOnlyDisplayFormat(s)} - #{dateOnlyDisplayFormat(e)}).
			Valinnoilla <strong>#{selected}</strong> avausta.
			<strong>#{numberFormat(selected/dur)}</strong> avausta päivässä.
		"""
		actinfo.innerHTML = """
			<strong style='color: blue'>#{numberFormat(likesPerPostTotal.value().average)}</strong> reaktiota
			ja
			<strong style='color: orange'>#{numberFormat(commentsPerPostTotal.value().average)}</strong> kommenttia
			per avaus.
		"""

		in_table = Math.min selected, tablelimit
		tablecounts.innerHTML = "#{in_table}/#{selected}"
	

	timechart
		.height height
		.transitionDuration transdur
		.brushOn true
		.x(d3.scaleTime().domain(time_extent) )
		.xUnits d3.timeWeeks
		.elasticY true
		.dimension weekDimension
		.compose [
			dc.lineChart(timechart)
				.group(postsPerDay, "Avauksia päivässä")
				.colors("black")
				.renderArea true
			dc.lineChart(timechart)
				.group(likesPerPost, "Reaktioita/avaus")
				.valueAccessor((d) -> d.value.average)
				.colors("blue")
				.useRightYAxis true
			dc.lineChart(timechart)
				.group(commentsPerPost, "Kommenttia/avaus")
				.valueAccessor((d) -> d.value.average)
				.colors("orange")
				.useRightYAxis true
			]
		.legend(dc.legend().x(50).y(20))
		.xAxisLabel "Päivämäärä"
		.yAxisLabel "Avauksia"
		.rightYAxisLabel "Reaktioita, Kommentteja"
	ndx.onChange update_timeinfo
	update_timeinfo()
	
	
	activityAverager = [
		(p, v) ->
			p.count += 1
			p.totalR += v.reactions; p.averageR = p.totalR/p.count
			p.totalC += v.comments; p.averageC = p.totalC/p.count
			return p
		(p, v) ->
			p.count -= 1
			p.totalR -= v.reactions
			p.totalC -= v.comments
			if p.count == 0
				p.averageR = 0
				p.averageC = 0
			else
				p.averageR = p.totalR/p.count
				p.averageC = p.totalC/p.count
			return p
		() -> totalR: 0, totalC: 0, count: 0, averageR: 0, averageP: 0
		]
	
	actGroup = pubtypeDimension.group().reduce(activityAverager...)
	actchart = dc.bubbleChart "#activity-bubble"
	actchart
		.dimension pubtypeDimension
		.height height
		.group actGroup
		.keyAccessor (d) -> d.value.averageR
		.valueAccessor (d) -> d.value.averageC
		.radiusValueAccessor (d) -> 2
		.colorAccessor (d) -> 0
		.x(d3.scaleLinear())
		.y(d3.scaleLinear())
		.elasticX true
		.elasticY true
		.xAxisPadding 2
		.yAxisPadding 2
		.xAxisLabel "Reaktiota/avaus"
		.yAxisLabel "Kommenttia/avaus"
	actchart.onClick = ->

	nticks = 3
	margins = left: 20, right: 10, top: 5, bottom: 50

	labeler = (d) ->
		d.key
		#total = total_selected.reduceCount().value()
		#"#{d.key} #{(d.value/total * 100).toFixed(0)} %"
	
	window.pubtypechart = dc.rowChart "#pubtype-chart"
	pubtypeGroup = pubtypeDimension.group()
	pubtypechart
		.height height
		.transitionDuration transdur
		.dimension pubtypeDimension
		.colorAccessor (d) -> 0
		.elasticX true
		.group pubtypeGroup
		.margins margins
		.label(labeler)
		.xAxis().ticks nticks
	
	window.publisherchart = dc.rowChart "#publisher-chart"
	publisherGroup = publisherDimension.group()
	publisherchart
		.height height
		.transitionDuration transdur
		.dimension publisherDimension
		.colorAccessor (d) -> 0
		.elasticX true
		.group publisherGroup
		.margins margins
		.label(labeler)
		.xAxis().ticks nticks

	window.interestchart = dc.rowChart "#interest-chart"
	interestchart
		.height height
		.transitionDuration transdur
		.dimension interestDimension
		.colorAccessor (d) -> 0
		.elasticX true
		.group interestDimension.group()
		.margins margins
		.label(labeler)
		.xAxis().ticks nticks
	
	domainDim = ndx.dimension (d) ->
		return d.domain if d.domain
		return "Linkitön"
	window.domainchart = dc.rowChart "#domain-chart"
	domainchart
		.height height
		.transitionDuration transdur
		.dimension domainDim
		.colorAccessor (d) -> 0
		.elasticX true
		.group domainDim.group()
		.cap 10
		.othersGrouper false
		.margins margins
		.xAxis().ticks nticks
	
	###
	getWeekday = (d) ->
		weekdayno = (d.dd.getDay() + 1)%7
		names = ["Ma", "Ti", "Ke", "To", "Pe", "La", "Su"]
		return "#{weekdayno}.#{names[weekdayno]}"
	
	getTod = (d) ->
		h = d.dd.getHours()
		return h
	weekday = ndx.dimension (d) ->
		[getWeekday(d), getTod(d)]
	
	heatColorMapping = d3.scaleLinear()
		.range(["white", "green"])
	
	heatColorRange = (chart) ->
		wtf = d3.extent(chart.data(), chart.colorAccessor())
		console.log wtf
		chart.colorDomain d3.extent(chart.data(), chart.colorAccessor())

	window.dateheat = dc.heatMap "#date-heat"
	dateheat
		.height height
		.transitionDuration transdur
		.dimension weekday
		.group weekday.group().reduceCount()
		.keyAccessor (d) -> d.key[0]
		.valueAccessor (d) -> d.key[1]
		.colorAccessor (d) -> d.value
		.colors heatColorMapping
		.on "preRender", heatColorRange
		.on "preRedraw", heatColorRange
		.margins margins
	###
	window.datatable = dc.dataTable(".dc-data-table")
	fb_group_id = "485003524967015"
	datatable
		.dimension(timeDimension)
		.order d3.descending
		.size tablelimit
		.columns [
			{label: "Ajankohta", format: (d) ->
				url = "https://www.facebook.com/groups/#{fb_group_id}/permalink/#{d.post_id}/"
				"<a href=\"#{url}\" target=\"_blank\">#{dateDisplayFormat(d.dd)}</a>"
			}
			{label: "Reaktioita", format: (d) -> d.reactions}
			{label: "Kommentteja", format: (d) -> d.comments}
			{label: "Lähde", format: (d) ->
				return "Linkitön" if not d.link
				url = d.link
				"<a href=\"#{url}\" target=\"_blank\">#{d.domain}</a>"
			}
			{label: "Julkaisutyyppi", format: (d) -> pubtypeDimension.accessor(d)}
			{label: "Julkaisija", format: (d) -> publisherDimension.accessor(d)}
			#{label: "Eturyhmä", format: (d) -> interestDimension.accessor(d)}
		]
		
	dc.renderAll()
	d3.select("#loader").style("display", "none")


