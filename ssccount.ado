

*! ssccount
*! v 1.0.0
*! Tim Morris
*! 30oct2015
/* If using GitHub, the history becomes irrelavant since you could access any 
previous version/state of the program using the commit ID (a hash generated at 
each commit).  git diff allows users to compare the changes across commits, and 
git log would print something similar to the lines below in the console.  */
*! 09jun2015  v 0.7  T Morris  Added smoothed line (lowess) to the graph drawn if graph option is specified.
*! 12feb2015  v 0.6  T Morris  Fixed issue with inappropriate warning message.
*! 22jan2015  v 0.5  T Morris  Changed name from getsschits to ssccount. Bug fixes and improvements. Updated help file.
*! 18dec2014  v 0.4  T Morris  Minor updates and fixes. Option -clear- added.
*! 07nov2014  v 0.3  T Morris  Created a command with error checking, automatic graph etc.

// Drop program from memory if already loaded
cap prog drop ssccount

// Downloads count of SSC hits and optionally graph for specified author and package
prog def ssccount

	version 13

	// Define syntax structure of program
	syntax , [ 	FRom(string) to(string) AUthor(string) clear Fillin(string)	 ///   
	GRaph PACKage(string) SAVing(string) REFresh DOTs noUPDate SCHeme(passthru) ]

	// Make sure you can get back to the same starting directory
	loc home `"`c(pwd)'"'
	
	// Turn dates into numbers
	if "`from'" == "" {
		local fromno 570
	}
	else if "`from'" != "" {
		tokenize "`from'", parse("m")
		local fromno = ym(`1',`3')
	}
	if "`to'" == "" {
		local tono = mofd(td("`c(current_date)'")) - 2
	}
	else if "`to'" != "" {
		tokenize "`to'", parse("m")
		local tono = ym(`1',`3')
	}
	
	// Variable names
	loc varnms package author hits date
	
	// Set the most recent month for the end peroid
	local currentmonth = mofd(td("`c(current_date)'")) - 2

	// Check for the subdirectory ssc in ADOPATH Personal, if it doesn't exist, 
	// create it, otherwise do nothing
	qui: dirfile, path(`"`c(sysdir_personal)'ssc"')

	// Check for existing archive file
	cap: confirm new file `"`c(sysdir_personal)'ssc/hotdb.dta"'
	
	// If the file does not exist build the db
	if _rc == 0 | `"`refresh'"' != "" {
			
		// Call subroutine to download and normalize all od the files
		getsscfiles, from(570) to(`currentmonth')	
			
		// Store file list in new macro
		loc sscfiles `r(sscfilelist)'
			
		// Load the oldest file
		qui: use `: word 1 of `sscfiles'', clear

		// Loop over tempfiles that were already normalized and downloaded
		forv i = 2/`: word count `sscfiles'' {
		
			// Append all of the temp files
			cap append using `: word `i' of `sscfiles''

		} // End Loop to build the database
		
		// Copy the package name and attempt to normalize the names
		qui: g x = trim(itrim(lower(package)))
		
		// Encode package names numerically
		qui: encode x, gen(cmdname)
		
		// Drop variables used to clean 
		drop x
		
		// Label the variables
		la var package "Package"
		la var author "Author"
		la var hits "Number of Downloads"
		la var mo "Date"
		la var cmdname "Numeric Encoded Package Name"
		
		// Set display formats
		format hits %9.0f
		format mo %tmMon_CCYY

		// Check for fillin option
		if `"`fillin'"' != "" {
		
			// Rectangularize data set by package name and month
			qui: fillin package mo
			
			// Replace missing values of hits
			qui: replace hits = `fillin' if mi(hits)
			
			// Drop the indicator for cases generated by fillin
			drop _fillin
			
		} // End IF Block for fillin option

		// Optimize the storage efficiency of the data
		qui: compress

		// Set the sort order of the data
		sort author package mo

		// Save the full db
		qui: save `"`c(sysdir_personal)'ssc/hotdb.dta"', replace
		
	} // End IF Block to construct the database
	
	// Check update option
	if `"`update'"' != "noupdate" {
	
		// Load the current db file
		qui: use `"`c(sysdir_personal)'ssc/hotdb.dta"', clear
		
		// Get the maximum value of the month variable
		qui: su mo
		
		// If the current month is greater than the maximum month
		if `r(max)' < `currentmonth' {
		
			// Loop over months between current maximum and current month
			getsscfiles, from(`= `r(max)' + 1') to(`currentmonth')
			
			// Load the existing database
			qui: use `"`c(sysdir_personal)'ssc/hotdb.dta"', clear
		
			// Append the files just created through the update process
			foreach v in `r(sscfilelist)' {
			
				// Append update files
				cap append using `v'
			
			} // End Loop over update files
		
			// Optimize the storage efficiency of the data
			qui: compress

			// Set the sort order of the data
			sort author package mo

			// Save the updates to the db
			qui: save `"`c(sysdir_personal)'ssc/hotdb.dta"', replace
			
		} // End IF Block for needed update case
	
		// If there are no new months available
		else {
		
			// Print message to console
			di as res "Current ssccount data is already current.  "	_n		 ///   
			"No updates will be applied at this time."
		
		} // End ELSE Block for no valid update time
		
	} // End ELSEIF Block for update option handling

	
	// If saving option was specified, check if the file exists and, if it does, that replace was specified.
	if `"`saving'"' != "" {
		_prefix_saving `saving'
		local saving `"`s(filename)'"'
		local replace `"`s(replace)'"'
		if `"`replace'"' == "" {
			confirm new file `"`s(filename)'"'
		}
	}
	
	// check that dates are reasonable
	if `fromno' < 570 {
		di as err "You specified from(`from'), which is before records began." _n ///   
		"Option from() must be later than 2007m7."
		exit
	}
	if `tono' < 570 {
		di as err "You specified to(`to'), which is before records began." _n "Option to() must be later than 2007m7."
		exit
	}
	if `fromno' > `tono' {
		di as err "Date given in from(first_month) is after that given in to(last_month)"
		exit
	}
	
	// Keep data for authors and packages specified
	if `"`package'"' != "" {
		qui: keep if package == upper("`package'")
	}
	if `"`author'"' != "" {
		qui: keep if regexm(lower(author),lower("`author'"))
	}
	quietly count
	if `r(N)' == 0 {
		if "`author'" == "" display as text "Found no results for package `package' from `from' to `to'"
		else if "`package'" == "" display as text "Found no results for author `author' from `from' to `to'"
		else display as text "Found no results for author `author' and package `package' from `from' to `to'"
	}

	// Cannot request a graph w/o specifying an author or package
	if "`graph'" != "" & "`author'" == "" & "`package'" == "" {

		// Print error message to the console for the user
		di as err "No authors or packages have been selected, "				 ///   
		"but the graph option has." _n "Too many graphs to be drawn."
		
		// Issue error code
		err 198
		
	} // End IF Block for invalid graph option
	
	// For valid graph option calls
	else if `"`graph'"' != "" {
		
		// Cross tab of programs by authors
		qui: ta cmdname author
		
		// For single program and single author records
		if `r(r)' == 1 & `r(c)' == 1 { 
		
			// Create the graph
			twoway (line hits mo) (lowess hits mo) , ytit("Number of hits")  ///   
			ylab(, format(%9.0f)) xlab(, angle(45)) ylab(, angle(0)) `scheme'
		
		} // End IF Block 
		
		else if `r(r)' == 1 & `r(c)' > 1 {

			noisily twoway (line hits mo) (lowess hits mo), 				 ///   
			by(author, note("")) ytit("Number of hits") 					 ///   
			ylab(, format(%9.0f)) xlab(, angle(45)) ylab(,a ngle(0)) `scheme'
		
		}
		
		else if `r(r)' > 1 & `r(c)' == 1 {
		
			noisily twoway (line hits mo) (lowess hits mo), 				 ///   
			by(cmdname, note("")) ytit("Number of hits") 				 	 ///   
			ylab(, format(%9.0f)) xlab(, angle(45)) ylab(, angle(0)) `scheme'

		}

		else if `r(r)' > 1 & `r(c)' > 1 {
			
			// Graph the data by author/package
			noisily twoway (line hits mo) (lowess hits mo),					 ///   
			by(author cmdname, note("")) ytit("Number of hits")				 ///   
			ylab(, format(%9.0f)) xlab(, angle(45)) ylab(, angle(0)) `scheme'

		}
		
	} // End ELSE IF Block for handling of the graph option

	if `"`saving'"' != "" {
		capture drop __*
		sort author package mo
		save `"`saving'"', `replace'
	}

	// If directory has changed go back to starting directory
	if `"`c(pwd)'"' != `"`home'"' cd `"`home'"'
	
// End of program definition	
end

// Defines subroutine to download files
prog def getsscfiles, rclass

	syntax, to(real) from(real)

	// First loop downloads/normalizes all of the data
	forv i = `from'/`to' {
	
		// Reserve namespace for each month's file
		tempfile hot`i'
		
		// Process dots
		if `"`dots'"' != "" di as text "." _continue
		
		// Attempt to load the file into memory
		cap: use "http://repec.org/docs/sschotP`i'.dta", clear

		// If file does not load
		if _rc != 0 {
		
			// Print error me
			di as err "Warning: file http://repec.org/docs/sschotP`i'.dta not found."

		} // End IF Block to handle files that do not load from the web
		
		// If the file loads from the web successfully
		else {
			
			// Build a local with valid months
			loc months `months' `i'
			
			// Check for month variable
			cap confirm v mo
			
			// If no month variable
			if _rc != 0 {
			
				// Generate the variable
				qui: g double mo = `i'
				
				// Set the display format
				format %tm mo
				
			} // End handling for files w/o month variables

			// Get all numeric variable names
			qui: ds, not(type string)
			
			// Get the hits variable name
			qui: ds `r(varlist)', not(f "%tm")
			
			// Rename the hits variable name to a standardized name
			rename `r(varlist)' hits
			
			// Save the temp file
			qui: save `hot`i''.dta, replace
			
			// Construct a list of filenames
			loc filelist `filelist' `hot`i''.dta
			
			// Return the tempfile name
			ret loc hot`i' `hot`i''
			
		} // End ELSE Block for downloaded files
		
	} // End Loop to download SSC Hot files
	
	// Return the file list
	ret loc sscfilelist `filelist'
	
// End the sub routine definition
end
