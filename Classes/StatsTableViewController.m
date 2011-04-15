//
//  StatsTableViewController.m
//  WordPress
//
//  Created by Dan Roundhill on 10/12/10.
//  Copyright 2010 WordPress. All rights reserved.
//

#import "StatsTableViewController.h"
#import "StatsTableCell.h"
#import "UITableViewActivityCell.h"
#import "WPcomLoginViewController.h"
#import "WPReachability.h"
#import "CPopoverManager.h"


@implementation StatsTableViewController

@synthesize viewsData, postViewsData, referrersData, searchTermsData, clicksData, reportTitle,
currentBlog, statsData, currentProperty, rootTag, 
statsTableData, leftColumn, rightColumn, xArray, yArray, xValues, yValues, wpcomLoginTable, 
statsPageControlViewController, apiKeyConn, viewsConn, postViewsConn, referrersConn, 
searchTermsConn, clicksConn, daysConn, weeksConn, monthsConn;
@synthesize blog;
#define LABEL_TAG 1 
#define VALUE_TAG 2 
#define FIRST_CELL_IDENTIFIER @"TrailItemCell" 
#define SECOND_CELL_IDENTIFIER @"RegularCell" 

- (void)dealloc {
	[viewsData release];
	[postViewsData release];
	[referrersData release];
	[searchTermsData release];
	[clicksData release];
	[reportTitle release];
	[currentBlog release];
	[statsData release];
	[currentProperty release];
	[rootTag release];
	[statsTableData release];
	[leftColumn release];
	[rightColumn release];
	[xArray release];
	[yArray release];
	[xValues release];
	[yValues release];
	[wpcomLoginTable release];
	[statsPageControlViewController release];
	[apiKeyConn release];
	[viewsConn release];
	[postViewsConn release];
	[referrersConn release];
	[searchTermsConn release];
	[clicksConn release];
	[daysConn release];
	[weeksConn release];
	[monthsConn release];
	[super dealloc];
}

- (void)viewDidLoad {
	[FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
	[super viewDidLoad];

	loadMorePostViews = 10;
	loadMoreReferrers = 10;
	loadMoreSearchTerms = 10;
	loadMoreClicks = 10;
	
	self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleGrouped];
	self.view.frame = CGRectMake(0, 0, 320, 460);
	self.tableView.sectionHeaderHeight = 30;
	appDelegate = (WordPressAppDelegate *)[[UIApplication sharedApplication] delegate];
	
	statsPageControlViewController = [[StatsPageControlViewController alloc] init];
	connectionToInfoMapping = CFDictionaryCreateMutable(
														kCFAllocatorDefault,
														0,
														&kCFTypeDictionaryKeyCallBacks,
														&kCFTypeDictionaryValueCallBacks);
	
	if (_refreshHeaderView == nil) {
		EGORefreshTableHeaderView *view = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, self.view.frame.size.width, self.tableView.bounds.size.height)];
		view.delegate = self;
		[self.tableView addSubview:view];
		_refreshHeaderView = view;
		[view release];
	}
	
	//  update the last update date
	[_refreshHeaderView refreshLastUpdatedDate];
		
	/*if (DeviceIsPad() == YES) {
		[self.view removeFromSuperview];
		[statsPageControlViewController initWithNibName:@"StatsPageControlViewController-iPad" bundle:nil];
		[self initWithNibName:@"StatsTableViewConroller-iPad" bundle:nil];
		[appDelegate showContentDetailViewController:self];
	}*/
	[self.tableView setBackgroundColor:[[[UIColor alloc] initWithRed:221.0f/255.0f green:221.0f/255.0f blue:221.0f/255.0f alpha:1.0] autorelease]];
}



- (void) viewWillAppear:(BOOL)animated {
	
    //reset booleans
    apiKeyFound = NO;
    dotorgLogin = NO;
    isRefreshingStats = NO;
    foundStatsData = NO;
    canceledAPIKeyAlert =  NO;
    
	if([[WPReachability sharedReachability] internetConnectionStatus] == NotReachable) {
		UIAlertView *errorView = [[UIAlertView alloc] 
								  initWithTitle: @"Communication Error" 
								  message: @"The internet connection appears to be offline." 
								  delegate: self 
								  cancelButtonTitle: @"OK" otherButtonTitles: nil];
		[errorView show];
		[errorView autorelease];
	}
	else
	{
		if (DeviceIsPad() == YES) {
			//[[[CPopoverManager instance] currentPopoverController] dismissPopoverAnimated:YES];
			//[appDelegate showContentDetailViewController:self];
		}
		
		//get this party started!
		if (!canceledAPIKeyAlert && !foundStatsData && !displayedLoginView)
			[self initStats]; 
	}
}

- (void)loadView {
    [super loadView];
    
	
}

-(void) initStats {
	
	NSString *apiKey = [appDelegate currentBlog].apiKey;
	if (apiKey == nil){
		//first run or api key was deleted
		[self getUserAPIKey];
	}
	else {
		statsRequest = YES;
		[self showLoadingDialog];
		[self refreshStats: 0 reportInterval: 0];
	}
}

-(void) showLoadingDialog{
	CGPoint offset = self.tableView.contentOffset;
	offset.y = - 65.0f;
	self.tableView.contentOffset = offset;
	[_refreshHeaderView egoRefreshScrollViewDidEndDragging:self.tableView];
}

-(void) hideLoadingDialog{
	[_refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:self.tableView];
}

-(void)getUserAPIKey {
	if (appDelegate.isWPcomAuthenticated)
	{
		[self showLoadingDialog];
		statsData = [[NSMutableData alloc] init];
		apiKeyConn = [[NSURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"http://public-api.wordpress.com/get-user-blogs/1.0"]] delegate:self];
		
		CFDictionaryAddValue(
							 connectionToInfoMapping,
							 apiKeyConn,
							 [NSMutableDictionary
							  dictionaryWithObject:[NSMutableData data]
							  forKey:@"apiKeyData"]);
	}
	else 
	{
		BOOL presentDialog = YES;
		if (dotorgLogin == YES && appDelegate.isWPcomAuthenticated == NO)
		{
			presentDialog = NO;
			dotorgLogin = NO;
		}
		
		if (presentDialog) {
			dotorgLogin = YES;
		
		if(DeviceIsPad() == YES) {
			WPcomLoginViewController *wpComLogin = [[WPcomLoginViewController alloc] initWithNibName:@"WPcomLoginViewController-iPad-stats" bundle:nil];	
            wpComLogin.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
			wpComLogin.modalPresentationStyle = UIModalPresentationFormSheet;
            wpComLogin.isStatsInitiated = YES;
			[appDelegate.splitViewController presentModalViewController:wpComLogin animated:YES];			
            [wpComLogin release];
		}
		else {
			dotorgLogin = YES;
			WPcomLoginViewController *wpComLogin = [[WPcomLoginViewController alloc] initWithNibName:@"WPcomLoginViewController" bundle:nil];	
			[appDelegate.navigationController presentModalViewController:wpComLogin animated:YES];
			[wpComLogin release];
		}
		UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"WordPress.com Stats" 
														 message:@"To load stats for your blog you will need to have the WordPress.com stats plugin installed and correctly configured as well as your WordPress.com login." 
														delegate:self cancelButtonTitle:@"Learn More" otherButtonTitles:nil] autorelease];
		alert.tag = 1;
		[alert addButtonWithTitle:@"I'm Ready!"];
		[alert show];
		}
		
	}
	
}

- (void) refreshStats: (int) titleIndex reportInterval: (int) intervalIndex {
	//load stats into NSMutableArray objects
	isRefreshingStats = YES;
	[self showLoadingDialog];
	foundStatsData = NO;
	
    //This block can be used for adding custom controls if desired by users down the road to load their own reports
    /*
    int days = -1;
	NSString *report;
	NSString *period;
	switch (intervalIndex) {
		case 0:
			days = 7;
			break;
		case 1:
			days = 30;
			break;
		case 2:
			days = 90;
			break;
		case 3:
			days = 365;
			break;
		case 4:
			days = -1;
			break;
	}
	
	if (days == 90){
		period = @"&period=week";
		days = 12;
	}
	else if (days == 365){
		period = @"&period=month";
		days = 11;
	}
	else if (days == -1){
		period = @"&period=month";
	}
	
	switch (titleIndex) {
		case 0:
			report = @"views";
			break;
		case 1:
			report = @"postviews";
			break;
		case 2:
			report = @"referrers";
			break;
		case 3:
			report = @"searchterms";
			break;
		case 4:
			report = @"clicks";
			break;
	}	
    */
	NSString *blogURL = [appDelegate currentBlog].hostURL;
	NSString *apiKey = [appDelegate currentBlog].apiKey;
	
	//request the 5 reports for display in the UITableView
	
	NSString *requestURL;
	NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
	//views
	requestURL = [NSString stringWithFormat: @"http://stats.wordpress.com/csv.php?api_key=%@&blog_uri=%@&format=xml&table=%@&days=%d%@", apiKey, blogURL, @"views", 7, @""];	
	[request setURL:[NSURL URLWithString:requestURL]];
	viewsConn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	CFDictionaryAddValue(
						 connectionToInfoMapping,
						 viewsConn,
						 [NSMutableDictionary
						  dictionaryWithObject:[NSMutableData data]
						  forKey:@"viewsData"]);
	
	//postviews
	requestURL = [NSString stringWithFormat: @"http://stats.wordpress.com/csv.php?api_key=%@&blog_uri=%@&format=xml&table=%@&days=%d%@&summarize", apiKey, blogURL, @"postviews", 7, @""];	
	[request setURL:[NSURL URLWithString:requestURL]];
	postViewsConn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	CFDictionaryAddValue(
						 connectionToInfoMapping,
						 postViewsConn,
						 [NSMutableDictionary
						  dictionaryWithObject:[NSMutableData data]
						  forKey:@"postViewsData"]);
	
	//referrers
	requestURL = [NSString stringWithFormat: @"http://stats.wordpress.com/csv.php?api_key=%@&blog_uri=%@&format=xml&table=%@&days=%d%@&summarize", apiKey, blogURL, @"referrers", 7, @""];	
	[request setURL:[NSURL URLWithString:requestURL]];
	referrersConn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	CFDictionaryAddValue(
						 connectionToInfoMapping,
						 referrersConn,
						 [NSMutableDictionary
						  dictionaryWithObject:[NSMutableData data]
						  forKey:@"referrersData"]);
	
	//search terms
	requestURL = [NSString stringWithFormat: @"http://stats.wordpress.com/csv.php?api_key=%@&blog_uri=%@&format=xml&table=%@&days=%d%@&summarize", apiKey, blogURL, @"searchterms", 7, @""];	
	[request setURL:[NSURL URLWithString:requestURL]];
	searchTermsConn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	CFDictionaryAddValue(
						 connectionToInfoMapping,
						 searchTermsConn,
						 [NSMutableDictionary
						  dictionaryWithObject:[NSMutableData data]
						  forKey:@"searchTermsData"]);
	
	//clicks
	requestURL = [NSString stringWithFormat: @"http://stats.wordpress.com/csv.php?api_key=%@&blog_uri=%@&format=xml&table=%@&days=%d%@&summarize", apiKey, blogURL, @"clicks", 7, @""];	
	[request setURL:[NSURL URLWithString:requestURL]];
	clicksConn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	CFDictionaryAddValue(
						 connectionToInfoMapping,
						 clicksConn,
						 [NSMutableDictionary
						  dictionaryWithObject:[NSMutableData data]
						  forKey:@"clicksData"]);
	
	
	//get the three header chart images
	statsData = [[NSMutableData alloc] init];
	statsRequest = YES;
	
	// 7 days
	requestURL = [NSString stringWithFormat: @"http://stats.wordpress.com/csv.php?api_key=%@&blog_uri=%@&format=xml&table=%@&days=%d%@", apiKey, blogURL, @"views", 7, @""];	
	[request setURL:[NSURL URLWithString:requestURL]];
	daysConn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	CFDictionaryAddValue(
						 connectionToInfoMapping,
						 daysConn,
						 [NSMutableDictionary
						  dictionaryWithObject:[NSMutableData data]
						  forKey:@"chartDaysData"]);
	// 10 weeks
	requestURL = [NSString stringWithFormat: @"http://stats.wordpress.com/csv.php?api_key=%@&blog_uri=%@&format=xml&table=%@&days=%d%@", apiKey, blogURL, @"views", 10, @"&period=week"];	
	[request setURL:[NSURL URLWithString:requestURL]];
	weeksConn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	CFDictionaryAddValue(
						 connectionToInfoMapping,
						 weeksConn,
						 [NSMutableDictionary
						  dictionaryWithObject:[NSMutableData data]
						  forKey:@"chartWeeksData"]);
	// 12 months
	requestURL = [NSString stringWithFormat: @"http://stats.wordpress.com/csv.php?api_key=%@&blog_uri=%@&format=xml&table=%@&days=%d%@", apiKey, blogURL, @"views", 11, @"&period=month"];	
	[request setURL:[NSURL URLWithString:requestURL]];
	[request setValue:@"wp-iphone" forHTTPHeaderField:@"User-Agent"];
	monthsConn = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	CFDictionaryAddValue(
						 connectionToInfoMapping,
						 monthsConn,
						 [NSMutableDictionary
						  dictionaryWithObject:[NSMutableData data]
						  forKey:@"chartMonthsData"]);
	[request release];
	statsRequest = YES;
}

- (void) startParsingStats: (NSString*) xmlString withReportType: (NSString*) reportType {
	statsTableData = nil;
	statsTableData = [[NSMutableArray alloc] init];
	xArray = [[NSMutableArray alloc] init];
	yArray = [[NSMutableArray alloc] init];
	NSData *data = [xmlString dataUsingEncoding:NSUTF8StringEncoding];
	NSXMLParser *statsParser = [[NSXMLParser alloc] initWithData:data];
	statsParser.delegate = self;
	[statsParser parse];
	[statsParser release];
	if ([xArray count] > 0){
		//set up the new data in the UI
		foundStatsData = YES;
		if ([reportType isEqualToString:@"chartDaysData"] || [reportType isEqualToString:@"chartWeeksData"] || [reportType isEqualToString:@"chartMonthsData"]){
			[self hideLoadingDialog];
			self.blog.lastStatsSync = [NSDate date];
			xValues = [[NSString alloc] init];
			xValues = [xArray componentsJoinedByString:@","];
			NSArray *sorted = [xArray sortedArrayUsingSelector:@selector(compare:)];
			
			//calculate some variables for the google chart
			int minValue = [[sorted objectAtIndex:0] intValue];
			int maxValue = [[sorted objectAtIndex:[sorted count] - 1] intValue];
			int minBuffer = round(minValue - (maxValue * .10));
			if (minBuffer < 0){
				minBuffer = 0;
			}
			int maxBuffer = round(maxValue + (maxValue * .10));
			//round to the lowest 10 for prettier charts
			for(int i = 0; i < 9; i++) {
				if(minBuffer % 10 == 0)
					break;
				else{
					minBuffer--;
				}
			}
			
			for(int i = 0; i < 9; i++) {
				if(maxBuffer % 10 == 0)
					break;
				else{
					maxBuffer++;
				}
			}
			
			int yInterval = maxBuffer / 10;
			//round the gap in y axis of the chart
			for(int i = 0; i < 9; i++) {
				if(yInterval % 10 == 0)
					break;
				else{
					yInterval++;
				}
			}
			
			NSMutableArray *dateCSV = [[NSMutableArray alloc] init];
            NSString *bgData = @"";
			if ([reportType isEqualToString:@"chartDaysData"]){
                bgData = @"|";
				for (NSString *dateVal in yArray) {
                    NSDateFormatter *df = [[NSDateFormatter alloc] init];
					[df setDateFormat:@"yyyy-MM-dd"];
					NSDate *tempDate = [df dateFromString: dateVal];
                    [df release];
					NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
					NSDateComponents *dateComponents = [gregorian components:(NSWeekdayCalendarUnit) fromDate:tempDate];
					NSInteger day = [dateComponents weekday];
					[gregorian release];
					if (day == 1 || day == 7){
						[dateCSV addObject: @"S"];
                        bgData = [NSString stringWithFormat:@"%@%d,", bgData, maxBuffer];
					}
					else if (day == 2){
						[dateCSV addObject: @"M"];
                        bgData = [NSString stringWithFormat:@"%@%@", bgData, @"0,"];
					}
					else if (day == 3 || day == 5){
						[dateCSV addObject: @"T"];
                        bgData = [NSString stringWithFormat:@"%@%@", bgData, @"0,"];
					}
					else if (day == 4){
						[dateCSV addObject: @"W"];
                        bgData = [NSString stringWithFormat:@"%@%@", bgData, @"0,"];
					}
					else if (day == 6){
						[dateCSV addObject: @"F"];
                        bgData = [NSString stringWithFormat:@"%@%@", bgData, @"0,"];
					}
					
				}
                bgData = [bgData substringToIndex:[bgData length] - 1];
			}
			else if ([reportType isEqualToString:@"chartWeeksData"])
			{
				for (NSString *dateVal in yArray) {
					[dateCSV addObject: [dateVal substringWithRange: NSMakeRange (5, 2)]];
				}
				
			}
			else if ([reportType isEqualToString:@"chartMonthsData"]){
				isRefreshingStats = NO;
				for (NSString *dateVal in yArray) {
                    NSDateFormatter *df = [[NSDateFormatter alloc] init];
					[df setDateFormat:@"yyyy-MM"];
					NSDate *tempDate = [df dateFromString: dateVal];
                    [df release];
					NSCalendar *gregorian = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
					NSDateComponents *dateComponents = [gregorian components:(NSMonthCalendarUnit) fromDate:tempDate];
					NSInteger i_month = [dateComponents month];
                    
                    NSString * dateString = [NSString stringWithFormat: @"%d", i_month];
                    
                    NSDateFormatter* dateFormatter = [[NSDateFormatter alloc] init];
                    [dateFormatter setDateFormat:@"MM"];
                    NSDate* myDate = [dateFormatter dateFromString:dateString];
                    [dateFormatter release];
                    
                    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
                    [formatter setDateFormat:@"MMM"];
                    NSString *stringFromDate = [formatter stringFromDate:myDate];
                    
                    
                    [dateCSV addObject: stringFromDate];
                    [formatter release];
					[gregorian release];
				}
				
			}
			NSString *dateValues = [[NSString alloc] initWithString:[dateCSV componentsJoinedByString:@"|"]];
			NSString *chartViewURL = [[[NSString alloc] initWithFormat: @"http://chart.apis.google.com/chart?chts=464646,20&cht=bvs&chg=100,20,1,0&chbh=a&chd=t:%@%@&chs=560x320&chl=%@&chxt=y,x&chds=%d,%d&chxr=0,%d,%d,%d&chf=c,lg,90,FFFFFF,0,FFFFFF,0.5&chco=a3bcd3,cccccc77&chls=4&chxs=0,464646,20,0,t|1,464646,20,0,t,ffffff&chxtc=0,0", xValues, bgData, dateValues, minBuffer,maxBuffer, minBuffer,maxBuffer, yInterval] autorelease];
			NSLog(@"google chart url: %@", chartViewURL);
			chartViewURL = [chartViewURL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
			statsRequest = YES;
			if ([reportType isEqualToString:@"chartDaysData"]) {
				statsPageControlViewController.chart1URL = chartViewURL;
				[statsPageControlViewController refreshImage: 1];
			}
			else if ([reportType isEqualToString:@"chartWeeksData"]){
				statsPageControlViewController.chart2URL = chartViewURL;
				[statsPageControlViewController refreshImage: 2];
			}
			else if ([reportType isEqualToString:@"chartMonthsData"]){
				statsPageControlViewController.chart3URL = chartViewURL;
				[statsPageControlViewController refreshImage: 3];
				//check the other charts
				if (statsPageControlViewController.chart2URL == nil) {
					statsPageControlViewController.chart2Error = YES;
					[statsPageControlViewController refreshImage: 2];
				}
				else if (statsPageControlViewController.chart1URL == nil) {
					statsPageControlViewController.chart1Error = YES;
					[statsPageControlViewController refreshImage: 1];
				}
			}
            [dateCSV release];
            [dateValues release];
		} //end chartData if statement
		else{
			if ([reportType isEqualToString:@"viewsData"]){
				self.viewsData = [[NSArray alloc] initWithArray:statsTableData copyItems:YES];
				[self.tableView reloadData];		
			}
			if ([reportType isEqualToString:@"postViewsData"]){
				self.postViewsData = [[NSArray alloc] initWithArray:statsTableData copyItems:YES];
				[self.tableView reloadData];		
			}
			if ([reportType isEqualToString:@"referrersData"]){
				self.referrersData = [[NSArray alloc] initWithArray:statsTableData copyItems:YES];
				[self.tableView reloadData];		
			}
			if ([reportType isEqualToString:@"searchTermsData"]){
				self.searchTermsData = [[NSArray alloc] initWithArray:statsTableData copyItems:YES];
				[self.tableView reloadData];		
			}
			if ([reportType isEqualToString:@"clicksData"]){
				self.clicksData = [[NSArray alloc] initWithArray:statsTableData copyItems:YES];
				[self.tableView reloadData];		
			}
		}
	}
	else {
		//NSLog(@"No data returned! oh noes!");
		if (!foundStatsData && ![reportType isEqualToString:@"apiKeyData"]){
			[self showNoDataFoundError];
		}
		
	}
	[self.view setHidden:NO];
	[self hideLoadingDialog];
}

-(void) showNoDataFoundError{
	[self.tableView.tableHeaderView removeFromSuperview];
	UILabel *errorMsg = [[UILabel alloc] init];
	errorMsg.text = @"No stats data found.  Please try again later.";
	self.tableView.tableHeaderView = errorMsg;
}

/*  NSURLConnection Methods  */

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
	if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
		[[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
	}
	else if ([challenge previousFailureCount] <= 1)
	{
		NSURLCredential *newCredential;
		NSString *s_username, *s_password;
		NSError *error = nil;
		s_username = [[NSUserDefaults standardUserDefaults] objectForKey:@"wpcom_username_preference"];
		s_password = [SFHFKeychainUtils getPasswordForUsername:s_username andServiceName:@"WordPress.com" error:&error];
		
		newCredential=[NSURLCredential credentialWithUser:s_username
												 password:s_password
											  persistence:NSURLCredentialPersistenceForSession];
		[[challenge sender] useCredential:newCredential forAuthenticationChallenge:challenge];
		dotorgLogin = YES;
	}
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	//add the data to the corresponding NSURLConnection object
	const NSMutableDictionary *connectionInfo = CFDictionaryGetValue(connectionToInfoMapping, connection);
	if ([connectionInfo objectForKey:@"apiKeyData"] != nil)
		[[connectionInfo objectForKey:@"apiKeyData"] appendData:data];
	else if ([connectionInfo objectForKey:@"postViewsData"] != nil)
		[[connectionInfo objectForKey:@"postViewsData"] appendData:data];
	else if ([connectionInfo objectForKey:@"referrersData"] != nil)
		[[connectionInfo objectForKey:@"referrersData"] appendData:data];
	else if ([connectionInfo objectForKey:@"searchTermsData"] != nil)
		[[connectionInfo objectForKey:@"searchTermsData"] appendData:data];
	else if ([connectionInfo objectForKey:@"clicksData"] != nil)
		[[connectionInfo objectForKey:@"clicksData"] appendData:data];
	else if ([connectionInfo objectForKey:@"viewsData"] != nil)
		[[connectionInfo objectForKey:@"viewsData"] appendData:data];
	else if ([connectionInfo objectForKey:@"chartDaysData"] != nil)
		[[connectionInfo objectForKey:@"chartDaysData"] appendData:data];
	else if ([connectionInfo objectForKey:@"chartWeeksData"] != nil)
		[[connectionInfo objectForKey:@"chartWeeksData"] appendData:data];
	else if ([connectionInfo objectForKey:@"chartMonthsData"] != nil)
		[[connectionInfo objectForKey:@"chartMonthsData"] appendData:data];
}

- (void) connectionDidFinishLoading: (NSURLConnection*) connection {
	const NSMutableDictionary *connectionInfo = CFDictionaryGetValue(connectionToInfoMapping, connection);
	//get the key name
	NSArray *keys = [connectionInfo allKeys];
	id aKey = [keys objectAtIndex:0];
	NSString *reportType = aKey;
	//format the xml response
	NSString *xmlString = [[[NSString alloc] initWithData:[connectionInfo objectForKey:aKey] encoding:NSUTF8StringEncoding] autorelease];
	[xmlString stringByReplacingOccurrencesOfString:@"\n" withString:@""];
	[xmlString stringByReplacingOccurrencesOfString:@"\t" withString:@""];
	WPLog(@"xml string = %@", xmlString);
	NSRange textRange;
	textRange =[xmlString rangeOfString:@"Error"];
	if ( xmlString != nil && textRange.location == NSNotFound ) {
		self.tableView.tableHeaderView = statsPageControlViewController.view;
		[self.tableView.tableHeaderView setHidden:NO];
		[self startParsingStats: xmlString withReportType: reportType];
	}
	else if (textRange.location != NSNotFound && ([connectionInfo objectForKey:@"viewsData"] != nil)){
		[self.tableView.tableHeaderView setHidden:YES];
		[connection cancel];
		[self hideLoadingDialog];
		//it's the wrong API key, prompt for WPCom login details again
		if(DeviceIsPad() == YES) {
            dotorgLogin = NO;
            isRefreshingStats = NO;
            foundStatsData = NO;
            canceledAPIKeyAlert =  NO;
			WPcomLoginViewController *wpComLogin = [[WPcomLoginViewController alloc] initWithNibName:@"WPcomLoginViewController-iPad-stats" bundle:nil];	
            wpComLogin.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
			wpComLogin.modalPresentationStyle = UIModalPresentationFormSheet;
            wpComLogin.isStatsInitiated = YES;
			[appDelegate.splitViewController presentModalViewController:wpComLogin animated:YES];			
			[wpComLogin release];
		}
		else {
			WPcomLoginViewController *wpComLogin = [[WPcomLoginViewController alloc] initWithNibName:@"WPcomLoginViewController" bundle:nil];	
			[appDelegate.navigationController presentModalViewController:wpComLogin animated:YES];
			[wpComLogin release];
		}
        displayedLoginView = YES;
		if (!statsAPIAlertShowing){
			[appDelegate currentBlog].apiKey = nil;
			[[appDelegate currentBlog] dataSave];
			UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Login Error" 
															 message:@"Please enter an administrator login for this blog and refresh." 
															delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:nil] autorelease];
			[alert addButtonWithTitle:@"OK"];
			[alert setTag:2];
			[alert show];
			statsAPIAlertShowing = YES;
		}
	}
	else {
		//NSLog(@"no data returned from api");
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	
	if ([response respondsToSelector:@selector(statusCode)])
	{
		int statusCode = [((NSHTTPURLResponse *)response) statusCode];
		if (statusCode >= 400)
		{
			[connection cancel];  // stop connecting; no more delegate messages
			NSDictionary *errorInfo
			= [NSDictionary dictionaryWithObject:[NSString stringWithFormat:
												  NSLocalizedString(@"Server returned status code %d",@""),
												  statusCode]
										  forKey:NSLocalizedDescriptionKey];
			NSError *statusError = [NSError errorWithDomain:@"org.wordpress.iphone"
													   code:statusCode
												   userInfo:errorInfo];
			[self connection:connection didFailWithError:statusError];
		}
	}
}

- (void)connection: (NSURLConnection *)connection didFailWithError: (NSError *)error
{	
	
	isRefreshingStats = NO;
	[self hideLoadingDialog];
	//UIAlertView *alert = [[[UIAlertView alloc] initWithTitle:@"Connection Error" 
	//												 message:[error errorInfo] 
	//												delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil] autorelease];
	//[alert show];
	//NSLog(@"ERROR: %@", [error localizedDescription]);
	
	[connection autorelease];
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace {
	return YES;
}

/*  XML Parsing  */

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
	self.currentProperty = [NSMutableString string];
	if (statsRequest) {
		if ([elementName isEqualToString:@"views"] || [elementName isEqualToString:@"postviews"] || [elementName isEqualToString:@"referrers"] 
			|| [elementName isEqualToString:@"clicks"] || [elementName isEqualToString:@"searchterms"] || [elementName isEqualToString:@"videoplays"] 
			|| [elementName isEqualToString:@"title"]) {
			rootTag = elementName;
		}
		else if ([elementName isEqualToString:@"total"]){
			//that'll do pig, that'll do.
			[parser abortParsing];
		}
		else {
			if ([elementName isEqualToString:@"post"]){
				leftColumn = [attributeDict objectForKey:@"title"];
			}
			else if ([elementName isEqualToString:@"day"] || [elementName isEqualToString:@"week"] || [elementName isEqualToString:@"month"]){
				leftColumn = [attributeDict objectForKey:@"date"];
			}
			else if ([elementName isEqualToString:@"referrer"] || [elementName isEqualToString:@"searchterm"]  || [elementName isEqualToString:@"click"]){
				leftColumn = [attributeDict objectForKey:@"value"];
			}
			yValues = [yValues stringByAppendingString: [leftColumn stringByAppendingString: @","]];
			if (leftColumn != nil){
				[yArray addObject: leftColumn];
			}
		}
	}
	
	//Uncomment for debugging
	/*for (id key in attributeDict) {
		
		NSLog(@"attribute: %@, value: %@", key, [attributeDict objectForKey:key]);
		
	}*/
	
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
	
	if (self.currentProperty) {
        [currentProperty appendString:string];
    }
    
	
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
	if (statsRequest){
		if ([elementName isEqualToString:@"post"] || [elementName isEqualToString:@"day"] || [elementName isEqualToString:@"referrer"] || 
			[elementName isEqualToString:@"week"] || [elementName isEqualToString:@"month"] || [elementName isEqualToString:@"searchterm"]
			|| [elementName isEqualToString:@"click"]){
			rightColumn = self.currentProperty;
			[xArray addObject: [NSNumber numberWithInt:[currentProperty intValue]]];
			NSArray *row = [[NSArray alloc] initWithObjects:leftColumn, rightColumn, nil];
			[statsTableData	addObject:row];
            [row release];
		}
	}
	else if ([elementName isEqualToString:@"apikey"]) {
		[appDelegate.currentBlog setValue:self.currentProperty forKey:@"apiKey"];
		[appDelegate.currentBlog dataSave];
		apiKeyFound = YES;
		[parser abortParsing];
		[self showLoadingDialog];
		//this will run the 'views' report for the past 7 days
		[self refreshStats: 0 reportInterval: 0];
	}
	
	self.currentProperty = nil;
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0 && alertView.tag == 1) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://wordpress.org/extend/plugins/stats/"]];
    }
	else if (buttonIndex == 0 && alertView.tag == 2) {
        statsAPIAlertShowing = NO;
		canceledAPIKeyAlert = YES;
		[appDelegate.navigationController dismissModalViewControllerAnimated: YES];
    }
	else if (buttonIndex == 1 && alertView.tag == 2) {
        statsAPIAlertShowing = NO;
    }
}



- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 5;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
	//tableView.backgroundColor = [UIColor clearColor];
	int count = 0;
	switch (section) {
		case 0:
			count = [viewsData count];
			break;
		case 1:
			if (loadMorePostViews >= [postViewsData count]){
				count = [postViewsData count];
			}
			else {
				count = loadMorePostViews + 1;
			}
			break;
		case 2:
			if (loadMoreReferrers >= [referrersData count]){
				count = [referrersData count];
			}
			else {
				count = loadMoreReferrers + 1;
			}
			break;
		case 3:
			if (loadMoreSearchTerms >= [searchTermsData count]){
				count = [searchTermsData count];
			}
			else {
				count = loadMoreSearchTerms + 1;
			}
			break;
		case 4:
			if (loadMoreClicks >= [clicksData count]){
				count = [clicksData count];
			}
			else {
				count = loadMoreClicks + 1;
			}
			break;
	}
	return count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	BOOL addLoadMoreFooter = NO;
	NSArray *row = [[[NSArray alloc] init] autorelease];
	switch (indexPath.section) {
		case 0:
			//reverse order so today is at top
			row = [viewsData objectAtIndex:(viewsData.count - 1) - indexPath.row];
			break;
		case 1:
			if (indexPath.row == loadMorePostViews){
				addLoadMoreFooter = YES;
			}
			else {
				if ((indexPath.row + 1) > [postViewsData count]){
					row = [postViewsData objectAtIndex:(indexPath.row - 1)];
				}
				else {
					row = [postViewsData objectAtIndex:indexPath.row];
				}
			}
			break;
		case 2:
			if (indexPath.row == loadMoreReferrers){
				addLoadMoreFooter = YES;
			}
			else {
				if ((indexPath.row + 1) > [referrersData count]){
					row = [referrersData objectAtIndex:(indexPath.row - 1)];
				}
				else {
					row = [referrersData objectAtIndex:indexPath.row];
				}
			}
			break;
		case 3:
			if (indexPath.row == loadMoreSearchTerms){
				addLoadMoreFooter = YES;
			}
			else {
				if ((indexPath.row + 1) > [searchTermsData count]){
					row = [searchTermsData objectAtIndex:(indexPath.row - 1)];
				}
				else {
					row = [searchTermsData objectAtIndex:indexPath.row];
				}
			}
			break;
		case 4:
			if (indexPath.row == loadMoreClicks){
				addLoadMoreFooter = YES;
			}
			else {
				if ((indexPath.row + 1) > [clicksData count]){
					row = [clicksData objectAtIndex:(indexPath.row - 1)];
				}
				else {
					row = [clicksData objectAtIndex:indexPath.row];
				}
			}
			break;
	}
	
	if (!addLoadMoreFooter){
        leftColumn = [[NSString alloc] initWithString: [row objectAtIndex:0]];
        rightColumn = [[NSString alloc] initWithString: [row objectAtIndex:1]];
	}

	NSString *MyIdentifier = [NSString stringWithFormat:@"MyIdentifier %i", indexPath.row];
	
	//if (cell == nil) {
		StatsTableCell *cell = [[[StatsTableCell alloc] initWithFrame:CGRectZero reuseIdentifier:MyIdentifier] autorelease];
		if (viewsData != nil) {

		UILabel *label = [[[UILabel	alloc] initWithFrame:CGRectMake(14.0, 0, 210.0, 
																		tableView.rowHeight)] autorelease]; 
			
		if (addLoadMoreFooter){
			[cell addColumn:280];
			label.frame = CGRectMake(14.0, 0, 266.0, tableView.rowHeight);
			label.font = [UIFont systemFontOfSize:14.0]; 
			label.text = @"Show more...";
			label.textAlignment = UITextAlignmentCenter; 
		}
		else {
			[cell addColumn:210];
			if (indexPath.section == 0 && indexPath.row == 0) {
				label.text = @"Today";
			}
			else if (indexPath.section == 0 && indexPath.row > 0){
				//special date formatting for first section
				 NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
				 [dateFormat setDateFormat:@"YYYY-MM-dd"];
				 NSDate *date = [dateFormat dateFromString:leftColumn];  
				 [dateFormat setDateFormat:@"MMMM d"];
				 label.text = [dateFormat stringFromDate:date];  
				 [dateFormat release];
			}
			else {
				label.text = leftColumn;
			}
			
			if (indexPath.section <= 1 || indexPath.section == 3)
				cell.selectionStyle = UITableViewCellSelectionStyleNone;
			label.font = [UIFont boldSystemFontOfSize:14.0]; 
			label.textAlignment = UITextAlignmentLeft; 
		}
			
		label.tag = LABEL_TAG; 
		if (indexPath.section == 0 || indexPath.section == 1){
			label.numberOfLines = 2;
		}
		
		label.textColor = [UIColor blackColor]; 
		label.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | 
		UIViewAutoresizingFlexibleHeight; 
		[cell.contentView addSubview:label]; 
		
		label =  [[[UILabel	alloc] initWithFrame:CGRectMake(226.0, 0, 60.0, tableView.rowHeight)] autorelease]; 
		
		if (!addLoadMoreFooter){
			[cell addColumn:70];
			label.tag = VALUE_TAG; 
			label.font = [UIFont systemFontOfSize:16.0]; 
			//add commas
			NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];	
			NSNumber *statDigits = [numberFormatter numberFromString:rightColumn];
			[numberFormatter setGroupingSeparator: @","];
			[numberFormatter setGroupingSize: 3];
			[numberFormatter setUsesGroupingSeparator: YES];
			label.text = [numberFormatter stringFromNumber: statDigits];
            [numberFormatter release];
			label.textAlignment = UITextAlignmentRight; 
			label.textColor = [[UIColor alloc] initWithRed:40.0 / 255 green:82.0 / 255 blue:137.0 / 255 alpha:1.0]; 
			label.adjustsFontSizeToFitWidth = YES;
			label.autoresizingMask = UIViewAutoresizingFlexibleRightMargin | 
			UIViewAutoresizingFlexibleHeight; 
			[cell.contentView addSubview:label];
		}
		}
	//}
	
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	// Navigation logic
	switch (indexPath.section) {
		case 1:
			if (indexPath.row == loadMorePostViews){
				loadMorePostViews += 10;
				[self.tableView reloadData];
			}
			break;
		case 2:
			if (indexPath.row == loadMoreReferrers){
				loadMoreReferrers += 10;
				[self.tableView reloadData];
			}
			else {
				[[UIApplication sharedApplication] openURL:[NSURL URLWithString: [[referrersData objectAtIndex:indexPath.row] objectAtIndex:0]]];
				[tableView deselectRowAtIndexPath:indexPath animated:YES];
			}
			break;
		case 3:
			if (indexPath.row == loadMoreSearchTerms){
				loadMoreSearchTerms += 10;
				[self.tableView reloadData];
			}
			break;
		case 4:
			if (indexPath.row == loadMoreClicks){
				loadMoreClicks += 10;
				[self.tableView reloadData];
			}
			else {
				[[UIApplication sharedApplication] openURL:[NSURL URLWithString: [[clicksData objectAtIndex:indexPath.row] objectAtIndex:0]]];
				[tableView deselectRowAtIndexPath:indexPath animated:YES];
			}
			break;
	}
}

- (UIView *) tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section 
{
    UILabel *label = [[[UILabel alloc] initWithFrame:CGRectMake(20, 3, tableView.bounds.size.width - 10, 18)] autorelease];
	switch (section) {
		case 0:
			if (viewsData != nil){
				label.text = @"Daily Views";
			}
			break;
		case 1:
			if (postViewsData != nil){
				label.text = @"Post Views";
			}
			break;
		case 2:
			if (referrersData != nil){
				label.text = @"Referrers";
			}
			break;
		case 3:
			if (referrersData != nil){
				label.text = @"Search Terms";
			}
			break;
		case 4:
			if (clicksData != nil){
				label.text = @"Clicks";
			}
			break;
	}
	
	UIView *headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 30)] autorelease];
	label.textColor = [UIColor colorWithRed:70.0f/255.0f green:70.0f/255.0f blue:70.0f/255.0f alpha:1.0];
	label.backgroundColor = [UIColor clearColor];
	label.shadowColor = [UIColor whiteColor];
	label.shadowOffset = CGSizeMake(1,1);
	label.font = [UIFont boldSystemFontOfSize:16.0];
	[headerView addSubview:label];
	return headerView;
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];	
	//cancel all possible connections
	if (viewsConn != nil)
		[viewsConn cancel];
	if (postViewsConn != nil)
		[postViewsConn cancel];
	if (referrersConn != nil)
		[referrersConn cancel];
	if (searchTermsConn != nil)
		[searchTermsConn cancel];
	if (clicksConn != nil)
		[clicksConn cancel];
	if (daysConn != nil)
		[daysConn cancel];
	if (weeksConn != nil)
		[weeksConn cancel];
	if (monthsConn != nil)
		[monthsConn cancel];
}

- (void)viewDidDisappear:(BOOL)animated {
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	// Return YES for supported orientations
	return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark -
#pragma mark UIScrollViewDelegate Methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView{
	[_refreshHeaderView egoRefreshScrollViewDidScroll:scrollView];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate{
	[_refreshHeaderView egoRefreshScrollViewDidEndDragging:scrollView];
}

#pragma mark -
#pragma mark EGORefreshTableHeaderDelegate Methods

- (void)egoRefreshTableHeaderDidTriggerRefresh:(EGORefreshTableHeaderView*)view{
	if (statsRequest)
		[self refreshStats:0 reportInterval:0];
}

- (BOOL)egoRefreshTableHeaderDataSourceIsLoading:(EGORefreshTableHeaderView*)view{
	return isRefreshingStats; // should return if data source model is reloading
}

- (NSDate*)egoRefreshTableHeaderDataSourceLastUpdated:(EGORefreshTableHeaderView*)view{
	return self.blog.lastStatsSync; // should return date data source was last changed
}

- (void)didReceiveMemoryWarning {
	[super didReceiveMemoryWarning]; // Releases the view if it doesn't have a superview
	// Release anything that's not essential, such as cached data
}

@end

