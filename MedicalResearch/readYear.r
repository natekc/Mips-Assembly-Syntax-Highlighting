benefit <- function() {
	# Payoff off .7 QALE 
	netPayoff <- calcPayoff(.7)

	# So far we've calc'd it for people not yet 18. But what about us old folks?
	# A low estimate: just include the people who were 18 in 2005
	# netPayoff <- netPayoff + sorted[5,2] * .7

	# High estimate:
	# Let's assume that the increase in QALE happens for everyone equally. This will overestimate the
	# benefit of research, since older people benefit less than 18y/os
	myData <- read.table("p2001_10.a", fill = TRUE, row.names = NULL, header=FALSE)
	over18in2005 <- myData[(myData[,3] > 18) & (myData[,2] == 2005),]
	totalOver18 <- sum(over18in2005[,4])
	netPayoff <- netPayoff + .7 * totalOver18
	return(netPayoff)
}

calcPayoff <- function(rawPayoffPerPerson) {
	files = c("p2001_10.a", "p2021_30.a", "p2041_50.a", "p2061_70.a", "p2081_90.a", "p2011_20.a", "p2031_40.a", "p2051_60.a", "p2071_80.a", "p2091_00.a")
	maxYears = length(files) * 10 - 5
	eighteens = matrix(nrow = maxYears, ncol = 2)

	i = 1
	for(file in files) {
		myData <- read.table(file, fill = TRUE, row.names = NULL, header=FALSE)
		# Only use years after 2005, and only people who are 18 so we don't double-count
		thisDecade <- myData[(myData[,3] == 18) & (myData[,2] > 2005),]
		eighteens[i:(i+nrow(thisDecade) - 1),1] = thisDecade[,2]
		eighteens[i:(i+nrow(thisDecade) - 1),2] = as.numeric(gsub(",", "", thisDecade[,4]))
		i = i + nrow(thisDecade)
	}
	sorted <- eighteens[order(eighteens[,1]),]

	# discount rate of 3% / year
	payoffPerYear <- rawPayoffPerPerson * .97^(sorted[,1] - 2006)

	# Net payoff is number of people * payoff rate	
	netPayoff <- sorted[,2] %*% payoffPerYear
}

cost <- function() {
	# NIH data only goes back to 1938, so skip the years before that
	# CPI data comes from US Dept of Labor: ftp://ftp.bls.gov/pub/special.requests/cpi/cpiai.txt
	cpis <- read.table("cpiClean", col.names = c("year", "cpi"), skip = 30)
	cpi2010 <- cpis[nrow(cpis),]$cpi	
	inflationAmt <- (cpi2010 - cpis$cpi) / cpis$cpi
	inflation <- data.frame(year = cpis$year, amount = inflationAmt)

	# The last year of CPI data is 2010 and NIH goes to 2009, so remove the last one from inflation
	inflation <- 1 + inflation[1:nrow(inflation)-1,]

	# Funding data comes from NIH: http://www.nih.gov/about/almanac/appropriations/index.htm
	funding <- read.table("nihFundingClean", col.names = c("year", "funding"))

	# funding is in $1,000s
	funding2010dollars <- as.numeric(gsub(",", "", funding$funding)) * inflation$amount * 1000
	return(data.frame(year = funding$year, funding = funding2010dollars))
}

productionCost <- function() {
	perPerson <- 4000
	pop <- read.table("p2001_10.a", fill = TRUE, row.names = NULL, header=FALSE)
	# The special row with "year" 2005999 contains the total population in 2005
	popIn2005 <- pop[pop[,2] == 2005999, 3]
	futureCost <- calcPayoff(perPerson)	
	return(perPerson * popIn2005 + futureCost)
}

estimates <- function() {
	benefit <- benefit()
	cost <- cost()
	proc <- productionCost()

	decadeBefore <- sum(cost[cost[,1] > 1984 & cost[,1] < 1995,2]) 
	twoDecBefore <- sum(cost[cost[,1] > 1974 & cost[,1] < 1995,2]) 
	oneDecInclPriv <- decadeBefore * 3
	twoDecInclPriv <- twoDecBefore * 3
	allNIH <- sum(cost[cost[,1] < 2006,2])
	all <- allNIH * 3
	oneDecPrivProd <- oneDecInclPriv + proc
	allAndProc <- all + proc
	labels = c("1985-1994, only public", "1975-1994, only public", "1985-1994, public & private", "1975-1994, public & private", "1938-2005, only public", "1938-2005, public & private", "1985-1994, pub, priv & proc", "1938-1994, pub, priv & proc")
	vals = c(decadeBefore, twoDecBefore, oneDecInclPriv, twoDecInclPriv, allNIH, all, oneDecPrivProd, allAndProc)
	icer = vals / benefit
	return(data.frame(labels = labels, cost = vals, icer = icer))
}

spendingGraph <- function() {
	c <- cost()
	plot(c$year, c$funding, main = "NIH funding", xlab = "Year", ylab = "Dollars (2010 equiv)")
}
