#import "PostSettingsViewController.h"
#import "WPSelectionTableViewController.h"
#import "WordPressAppDelegate.h"
#import "WPPopoverBackgroundView.h"

#define kPasswordFooterSectionHeight         68.0f
#define kResizePhotoSettingSectionHeight     60.0f
#define TAG_PICKER_STATUS       0
#define TAG_PICKER_VISIBILITY   1
#define TAG_PICKER_DATE         2
#define TAG_PICKER_FORMAT       3

@interface PostSettingsViewController (Private)

- (void)showPicker:(UIView *)picker;
- (void)geocodeCoordinate:(CLLocationCoordinate2D)c;

@end

@implementation PostSettingsViewController
@synthesize postDetailViewController, postFormatTableViewCell;

#pragma mark -
#pragma mark Lifecycle Methods

- (void)dealloc {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
	if (locationManager) {
		locationManager.delegate = nil;
		[locationManager stopUpdatingLocation];
	}
	if (reverseGeocoder) {
		[reverseGeocoder cancelGeocode];
	}
	mapView.delegate = nil;
}

- (void)viewDidLoad {
    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showFeaturedImageUploader:) name:@"UploadingFeaturedImage" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(featuredImageUploadSucceeded:) name:FeaturedImageUploadSuccessful object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(featuredImageUploadFailed:) name:FeaturedImageUploadFailed object:nil];
    
    [tableView setBackgroundView:nil];
    [tableView setBackgroundColor:[UIColor clearColor]]; //Fix for black corners on iOS4. http://stackoverflow.com/questions/1557856/black-corners-on-uitableview-group-style
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"settings_bg"]];
    
    statusTitleLabel.text = NSLocalizedString(@"Status", @"The status of the post. Should be the same as in core WP.");
    visibilityTitleLabel.text = NSLocalizedString(@"Visibility", @"The visibility settings of the post. Should be the same as in core WP.");
    postFormatTitleLabel.text = NSLocalizedString(@"Post Format", @"The post formats available for the post. Should be the same as in core WP.");
    passwordTextField.placeholder = NSLocalizedString(@"Enter a password", @"");
    NSMutableArray *allStatuses = [NSMutableArray arrayWithArray:[postDetailViewController.apost availableStatuses]];
    [allStatuses removeObject:NSLocalizedString(@"Private", @"Privacy setting for posts set to 'Private'. Should be the same as in core WP.")];
    statusList = [NSArray arrayWithArray:allStatuses];
    visibilityList = [NSArray arrayWithObjects:NSLocalizedString(@"Public", @"Privacy setting for posts set to 'Public' (default). Should be the same as in core WP."), NSLocalizedString(@"Password protected", @"Privacy setting for posts set to 'Password protected'. Should be the same as in core WP."), NSLocalizedString(@"Private", @"Privacy setting for posts set to 'Private'. Should be the same as in core WP."), nil];
    formatsList = postDetailViewController.post.blog.sortedPostFormatNames;

    isShowingKeyboard = NO;
    
    CGRect pickerFrame;
	if (IS_IPAD)
		pickerFrame = CGRectMake(0.0f, 0.0f, 320.0f, 216.0f);
	else 
		pickerFrame = CGRectMake(0.0f, 44.0f, 320.0f, 216.0f);
    
    pickerView = [[UIPickerView alloc] initWithFrame:pickerFrame];
    pickerView.delegate = self;
    pickerView.dataSource = self;
    pickerView.showsSelectionIndicator = YES;
        
    datePickerView = [[UIDatePicker alloc] initWithFrame:pickerView.frame];
    datePickerView.minuteInterval = 5;
    [datePickerView addTarget:self action:@selector(datePickerChanged) forControlEvents:UIControlEventValueChanged];

    passwordTextField.returnKeyType = UIReturnKeyDone;
	passwordTextField.delegate = self;
	
	if (postDetailViewController.post) {
		locationManager = [[CLLocationManager alloc] init];
		locationManager.delegate = self;
		locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters;
		locationManager.distanceFilter = 10;
		
		// FIXME: only add tag if it's a new post. If user removes tag we shouldn't try to add it again
		if (postDetailViewController.post.geolocation == nil // Only if there is no geotag
//			&& ![postDetailViewController.post hasRemote]    // and post is new (don't follow this way, instead tale look the line below)
			&& [postDetailViewController isAFreshlyCreatedDraft] //just a fresh draft. the line above doesn't take in consideration the case of a local draft without location
			&& [CLLocationManager locationServicesEnabled]
			&& postDetailViewController.post.blog.geolocationEnabled) {
			isUpdatingLocation = YES;
			[locationManager startUpdatingLocation];
		}
	}
    
    featuredImageView.layer.shadowOffset = CGSizeMake(0.0, 1.0f);
    featuredImageView.layer.shadowColor = [[UIColor blackColor] CGColor];
    featuredImageView.layer.shadowOpacity = 0.5f;
    featuredImageView.layer.shadowRadius = 1.0f;
    
    // Check if blog supports featured images
    id supportsFeaturedImages = [postDetailViewController.post.blog getOptionValue:@"post_thumbnail"];
    if (supportsFeaturedImages != nil) {
        blogSupportsFeaturedImage = [supportsFeaturedImages boolValue];
        if (blogSupportsFeaturedImage && postDetailViewController.post.post_thumbnail != nil) {
            // Download the current featured image
            [featuredImageView setHidden:YES];
            [featuredImageLabel setText:NSLocalizedString(@"Loading Featured Image", @"Loading featured image in post settings")];
            [featuredImageLabel setHidden:NO];
            [featuredImageSpinner setHidden:NO];
            if (!featuredImageSpinner.isAnimating)
                [featuredImageSpinner startAnimating];
            [tableView reloadData];
            
            [postDetailViewController.post getFeaturedImageURLWithSuccess:^{
                if (postDetailViewController.post.featuredImageURL) {
                    NSURL *imageURL = [[NSURL alloc] initWithString:postDetailViewController.post.featuredImageURL];
                    if (imageURL) {
                        [featuredImageTableViewCell setSelectionStyle:UITableViewCellSelectionStyleNone];
                        [featuredImageView setImageWithURL:imageURL];
                        [featuredImageView setHidden:NO];
                        [featuredImageSpinner stopAnimating];
                        [featuredImageSpinner setHidden:YES];
                        [featuredImageLabel setHidden:YES];
                    }
                }
            } failure:^(NSError *error) {
                [featuredImageView setHidden:YES];
                [featuredImageSpinner stopAnimating];
                [featuredImageSpinner setHidden:YES];
                [featuredImageLabel setText:NSLocalizedString(@"Could not download Featured Image.", @"Featured image could not be downloaded for display in post settings.")];
            }];
        }
    }
}

- (void)viewDidUnload {
    [super viewDidUnload];
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [FileLogger log:@"%@ %@", self, NSStringFromSelector(_cmd)];
    [locationManager stopUpdatingLocation];
    locationManager.delegate = nil;
    locationManager = nil;
    
    mapView = nil;
    
    [reverseGeocoder cancelGeocode];
    reverseGeocoder = nil;
    
    statusTitleLabel = nil;
    visibilityTitleLabel = nil;
    postFormatTitleLabel = nil;
    passwordTextField = nil;
    featuredImageView = nil;
    featuredImageTableViewCell = nil;
    featuredImageLabel = nil;
    featuredImageLabel = nil;
    postFormatTableViewCell = nil;

}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadData];
	[statusTableViewCell becomeFirstResponder];
}

- (void)didReceiveMemoryWarning {
    WPLog(@"%@ %@", self, NSStringFromSelector(_cmd));
    [super didReceiveMemoryWarning];
}

#pragma mark -
#pragma mark Rotation Methods

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return [super shouldAutorotateToInterfaceOrientation:interfaceOrientation];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self reloadData];
}


#pragma mark -
#pragma mark Instance Methods

- (void)endEditingAction:(id)sender {
	if (passwordTextField != nil){
        [passwordTextField resignFirstResponder];
	}
}

- (void)endEditingForTextFieldAction:(id)sender {
    [passwordTextField endEditing:YES];
}

- (void)reloadData {
    passwordTextField.text = postDetailViewController.apost.password;
	
    [tableView reloadData];
}

- (void)datePickerChanged {
    postDetailViewController.apost.dateCreated = datePickerView.date;
	[postDetailViewController refreshButtons];
    [tableView reloadData];
}

#pragma mark -
#pragma mark TextField Delegate Methods

- (void)textFieldDidEndEditing:(UITextField *)textField {
	postDetailViewController.apost.password = textField.text;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}


#pragma mark -
#pragma mark TableView Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    NSInteger sections = 1; // Always have the status section
	if (postDetailViewController.post) {
        sections += 1; // Post formats
        if (blogSupportsFeaturedImage)
            sections += 1;
        if (postDetailViewController.post.blog.geolocationEnabled) {
            sections += 1; // Geolocation
        }
	}
    return sections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0) {
		return 3;
    } else if (section == 1) {
        return 1;
    } else if (section == 2 && blogSupportsFeaturedImage) {
        if (postDetailViewController.post.post_thumbnail && !isUploadingFeaturedImage)
            return 2;
        else
            return 1;
	} else if ((section == 2 && !blogSupportsFeaturedImage) || section == 3) {
		if (postDetailViewController.post.geolocation)
			return 3; // Add/Update | Map | Remove
		else
			return 1; // Add
	}

    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == 0)
		return NSLocalizedString(@"Publish", @"The grandiose Publish button in the Post Editor! Should use the same translation as core WP.");
	else if (section == 1)
		return NSLocalizedString(@"Post Format", @"For setting the format of a post.");
    else if ((section == 2 && blogSupportsFeaturedImage))
		return NSLocalizedString(@"Featured Image", @"Label for the Featured Image area in post settings.");
	else if ((section == 2 && !blogSupportsFeaturedImage) || section == 3)
		return NSLocalizedString(@"Geolocation", @"Label for the geolocation feature (tagging posts by their physical location).");
	else
		return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	switch (indexPath.section) {
	case 0:
		switch (indexPath.row) {
			case 0:
				if (([postDetailViewController.apost.dateCreated compare:[NSDate date]] == NSOrderedDescending)
					&& ([postDetailViewController.apost.status isEqualToString:@"publish"])) {
					statusLabel.text = NSLocalizedString(@"Scheduled", @"If a post is scheduled for later, this string is used for the post's status. Should use the same translation as core WP.");
				} else {
					statusLabel.text = postDetailViewController.apost.statusTitle;
				}
				if ([postDetailViewController.apost.status isEqualToString:@"private"])
					statusTableViewCell.selectionStyle = UITableViewCellSelectionStyleNone;
				else
					statusTableViewCell.selectionStyle = UITableViewCellSelectionStyleBlue;
				
				return statusTableViewCell;
				break;
			case 1:
				if (postDetailViewController.apost.password) {
					passwordTextField.text = postDetailViewController.apost.password;
					passwordTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
					visibilityLabel.text = NSLocalizedString(@"Password protected", @"Privacy setting for posts set to 'Password protected'. Should be the same as in core WP.");
				} else if ([postDetailViewController.apost.status isEqualToString:@"private"]) {
					visibilityLabel.text = NSLocalizedString(@"Private", @"Privacy setting for posts set to 'Private'. Should be the same as in core WP.");
				} else {
					visibilityLabel.text = NSLocalizedString(@"Public", @"Privacy setting for posts set to 'Public' (default). Should be the same as in core WP.");
				}
				
				return visibilityTableViewCell;
				break;
			case 2:
			{
				if (postDetailViewController.apost.dateCreated) {
					if ([postDetailViewController.apost.dateCreated compare:[NSDate date]] == NSOrderedDescending) {
						publishOnLabel.text = NSLocalizedString(@"Scheduled for", @"Scheduled for [date]");
					} else {
						publishOnLabel.text = NSLocalizedString(@"Published on", @"Published on [date]");
					}
					
					NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
					[dateFormatter setDateStyle:NSDateFormatterMediumStyle];
					[dateFormatter setTimeStyle:NSDateFormatterNoStyle];
					publishOnDateLabel.text = [dateFormatter stringFromDate:postDetailViewController.apost.dateCreated];
				} else {
					publishOnLabel.text = NSLocalizedString(@"Publish   ", @""); //dorky spacing fix
					publishOnDateLabel.text = NSLocalizedString(@"Immediately", @"");
				}
				// Resize labels properly
				CGRect frame = publishOnLabel.frame;
				CGSize size = [publishOnLabel.text sizeWithFont:publishOnLabel.font];
				frame.size.width = size.width;
				publishOnLabel.frame = frame;
				frame = publishOnDateLabel.frame;
				frame.origin.x = publishOnLabel.frame.origin.x + publishOnLabel.frame.size.width + 8;
				frame.size.width = publishOnTableViewCell.frame.size.width - frame.origin.x - 8;
				publishOnDateLabel.frame = frame;
				
				return publishOnTableViewCell;
			}
			default:
				break;
		}
		break;
    case 1: // Post format
        {
            if ([formatsList count] != 0) {
                postFormatLabel.text = postDetailViewController.post.postFormatText;
            }
            return postFormatTableViewCell;
        }
	case 2: 
        if (blogSupportsFeaturedImage) {
            if (!postDetailViewController.post.post_thumbnail && !isUploadingFeaturedImage) {
                UITableViewActivityCell *activityCell = (UITableViewActivityCell *)[tableView dequeueReusableCellWithIdentifier:@"CustomCell"];
                if (activityCell == nil) {
                    NSArray *topLevelObjects = [[NSBundle mainBundle] loadNibNamed:@"UITableViewActivityCell" owner:nil options:nil];
                    for(id currentObject in topLevelObjects)
                    {
                        if([currentObject isKindOfClass:[UITableViewActivityCell class]])
                        {
                            activityCell = (UITableViewActivityCell *)currentObject;
                            break;
                        }
                    }
                }
                [activityCell.textLabel setText:@"Set Featured Image"];
                return activityCell;
                
                
            } else {
                switch (indexPath.row) {
                    case 0:
                        if (featuredImageTableViewCell == nil) {
                            NSArray *topLevelObjects = [[NSBundle mainBundle] loadNibNamed:@"UITableViewActivityCell" owner:nil options:nil];
                            for(id currentObject in topLevelObjects) {
                                if([currentObject isKindOfClass:[UITableViewActivityCell class]]) {
                                    featuredImageTableViewCell = (UITableViewActivityCell *)currentObject;
                                    break;
                                }
                            }
                        }
                        return featuredImageTableViewCell;
                        break;
                    case 1: {
                        UITableViewActivityCell *activityCell = (UITableViewActivityCell *)[tableView dequeueReusableCellWithIdentifier:@"CustomCell"];
                        if (activityCell == nil) {
                            NSArray *topLevelObjects = [[NSBundle mainBundle] loadNibNamed:@"UITableViewActivityCell" owner:nil options:nil];
                            for(id currentObject in topLevelObjects)
                            {
                                if([currentObject isKindOfClass:[UITableViewActivityCell class]])
                                {
                                    activityCell = (UITableViewActivityCell *)currentObject;
                                    break;
                                }
                            }
                        }
                        [activityCell.textLabel setText: NSLocalizedString(@"Remove Featured Image", "Remove featured image from post")];
                        return activityCell;
                        break;
                    }
                        
                }
            }
        } else {
            return [self getGeolactionCellWithIndexPath: indexPath];
        }
        break;
    case 3:
        return [self getGeolactionCellWithIndexPath: indexPath];
        break;
	}
    
    return nil;
}

- (UITableViewCell*) getGeolactionCellWithIndexPath: (NSIndexPath*)indexPath {
    switch (indexPath.row) {
        case 0: // Add/update location
        {
            if (addGeotagTableViewCell == nil) {
                NSArray *topLevelObjects = [[NSBundle mainBundle] loadNibNamed:@"UITableViewActivityCell" owner:nil options:nil];
                for(id currentObject in topLevelObjects) {
                    if([currentObject isKindOfClass:[UITableViewActivityCell class]]) {
                        addGeotagTableViewCell = (UITableViewActivityCell *)currentObject;
                        break;
                    }
                }
            }
            if (isUpdatingLocation) {
                addGeotagTableViewCell.textLabel.text = NSLocalizedString(@"Finding your location...", @"Geo-tagging posts, status message when geolocation is found.");
                [addGeotagTableViewCell.spinner startAnimating];
            } else {
                [addGeotagTableViewCell.spinner stopAnimating];
                if (postDetailViewController.post.geolocation) {
                    addGeotagTableViewCell.textLabel.text = NSLocalizedString(@"Update Location", @"Gelocation feature to update physical location.");
                } else {
                    addGeotagTableViewCell.textLabel.text = NSLocalizedString(@"Add Location", @"Geolocation feature to add location.");
                }
            }
            return addGeotagTableViewCell;
            break;
        }
        case 1:
        {
            NSLog(@"Reloading map");
            if (mapGeotagTableViewCell == nil)
                mapGeotagTableViewCell = [[UITableViewCell alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 188)];
            if (mapView == nil)
                mapView = [[MKMapView alloc] initWithFrame:CGRectMake(10, 0, 300, 130)];
            [mapView removeAnnotation:annotation];
            annotation = [[PostAnnotation alloc] initWithCoordinate:postDetailViewController.post.geolocation.coordinate];
            [mapView addAnnotation:annotation];
            
            if (addressLabel == nil)
                addressLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 130, 280, 30)];
            if (coordinateLabel == nil)
                coordinateLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 162, 280, 20)];
            
            // Set center of map and show a region of around 200x100 meters
            MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(postDetailViewController.post.geolocation.coordinate, 200, 100);
            [mapView setRegion:region animated:YES];
            if (address) {
                addressLabel.text = address;
            } else {
                addressLabel.text = NSLocalizedString(@"Finding address...", @"Used for Geo-tagging posts.");
                [self geocodeCoordinate:postDetailViewController.post.geolocation.coordinate];
            }
            addressLabel.font = [UIFont boldSystemFontOfSize:16];
            addressLabel.textColor = [UIColor darkGrayColor];
            CLLocationDegrees latitude = postDetailViewController.post.geolocation.latitude;
            CLLocationDegrees longitude = postDetailViewController.post.geolocation.longitude;
            int latD = trunc(fabs(latitude));
            int latM = trunc((fabs(latitude) - latD) * 60);
            int lonD = trunc(fabs(longitude));
            int lonM = trunc((fabs(longitude) - lonD) * 60);
            NSString *latDir = (latitude > 0) ? NSLocalizedString(@"North", @"Used for Geo-tagging posts by latitude and longitude. Basic form.") : NSLocalizedString(@"South", @"Used for Geo-tagging posts by latitude and longitude. Basic form.");
            NSString *lonDir = (longitude > 0) ? NSLocalizedString(@"East", @"Used for Geo-tagging posts by latitude and longitude. Basic form.") : NSLocalizedString(@"West", @"Used for Geo-tagging posts by latitude and longitude. Basic form.");
            if (latitude == 0.0) latDir = @"";
            if (longitude == 0.0) lonDir = @"";
            
            coordinateLabel.text = [NSString stringWithFormat:@"%i°%i' %@, %i°%i' %@",
                                    latD, latM, latDir,
                                    lonD, lonM, lonDir];
            //				coordinateLabel.text = [NSString stringWithFormat:@"%.6f, %.6f",
            //										postDetailViewController.post.geolocation.latitude,
            //										postDetailViewController.post.geolocation.longitude];
            coordinateLabel.font = [UIFont italicSystemFontOfSize:13];
            coordinateLabel.textColor = [UIColor darkGrayColor];
            
            [mapGeotagTableViewCell addSubview:mapView];
            [mapGeotagTableViewCell addSubview:addressLabel];
            [mapGeotagTableViewCell addSubview:coordinateLabel];
            
            return mapGeotagTableViewCell;
            break;
        }
        case 2:
        {
            if (removeGeotagTableViewCell == nil)
                removeGeotagTableViewCell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"RemoveGeotag"];
            removeGeotagTableViewCell.textLabel.text = NSLocalizedString(@"Remove Location", @"Used for Geo-tagging posts by latitude and longitude. Basic form.");
            removeGeotagTableViewCell.textLabel.textAlignment = UITextAlignmentCenter;
            return removeGeotagTableViewCell;
            break;
        }
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ((indexPath.section == 0) && (indexPath.row == 1) && (postDetailViewController.apost.password))
        return 88.f;
    else if (
             (!blogSupportsFeaturedImage && (indexPath.section == 2) && (indexPath.row == 1))
             || (blogSupportsFeaturedImage && (postDetailViewController.post.post_thumbnail || isUploadingFeaturedImage) && indexPath.section == 2 && indexPath.row == 0)
             || (blogSupportsFeaturedImage && (indexPath.section == 3) && (indexPath.row == 1))
             )
		return 188.0f;
	else
        return 44.0f;
}


- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	switch (indexPath.section) {
		case 0:
			switch (indexPath.row) {
				case 0:
				{
					if ([postDetailViewController.apost.status isEqualToString:@"private"])
						break;

					pickerView.tag = TAG_PICKER_STATUS;
					[pickerView reloadAllComponents];
					[pickerView selectRow:[statusList indexOfObject:postDetailViewController.apost.statusTitle] inComponent:0 animated:NO];
					[self showPicker:pickerView];
					break;
				}
				case 1:
				{
					pickerView.tag = TAG_PICKER_VISIBILITY;
					[pickerView reloadAllComponents];
					[pickerView selectRow:[visibilityList indexOfObject:visibilityLabel.text] inComponent:0 animated:NO];
					[self showPicker:pickerView];
					break;
				}
				case 2:
					datePickerView.tag = TAG_PICKER_DATE;
					if (postDetailViewController.apost.dateCreated)
						datePickerView.date = postDetailViewController.apost.dateCreated;
					else
						datePickerView.date = [NSDate date];            
					[self showPicker:datePickerView];
					break;

				default:
					break;
			}
			break;
        case 1:
        {
            if( [formatsList count] == 0 ) break;
            pickerView.tag = TAG_PICKER_FORMAT;
            [pickerView reloadAllComponents];
            if ([formatsList count] != 0 && ([formatsList indexOfObject:postDetailViewController.post.postFormatText] != NSNotFound)) {
                [pickerView selectRow:[formatsList indexOfObject:postDetailViewController.post.postFormatText] inComponent:0 animated:NO];
            }
            [self showPicker:pickerView];
            break;
        }
		case 2:
            if (blogSupportsFeaturedImage) {
                UITableViewCell *cell = [aTableView cellForRowAtIndexPath:indexPath];
                switch (indexPath.row) {
                    case 0:
                        if (!postDetailViewController.post.post_thumbnail) {
                            
                            [postDetailViewController.postMediaViewController showPhotoPickerActionSheet:cell fromRect:cell.frame isFeaturedImage:YES];
                        }
                        break;
                    case 1:
                        actionSheet = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Remove this Featured Image?", @"Prompt when removing a featured image from a post") delegate:self cancelButtonTitle:NSLocalizedString(@"Cancel", "Cancel a prompt") destructiveButtonTitle:NSLocalizedString(@"Remove", @"Remove an image/posts/etc") otherButtonTitles:nil];
                        [actionSheet showFromRect:cell.frame inView:self.view animated:YES];
                        break;
                }
            } else {
                switch (indexPath.row) {
                    case 0:
                        if (!isUpdatingLocation) {
                            // Add or replace geotag
                            isUpdatingLocation = YES;
                            [locationManager startUpdatingLocation];
                        }
                        break;
                    case 2:
                        if (isUpdatingLocation) {
                            // Cancel update
                            isUpdatingLocation = NO;
                            [locationManager stopUpdatingLocation];
                        }
                        postDetailViewController.post.geolocation = nil;
                        postDetailViewController.hasLocation.enabled = NO;
                        [postDetailViewController refreshButtons];
                        break;
                }
                [tableView reloadData];
            }
            break;
          case 3:
            switch (indexPath.row) {
                case 0:
                    if (!isUpdatingLocation) {
                        // Add or replace geotag
                        isUpdatingLocation = YES;
                        [locationManager startUpdatingLocation];
                    }
                    break;
                case 2:
                    if (isUpdatingLocation) {
                        // Cancel update
                        isUpdatingLocation = NO;
                        [locationManager stopUpdatingLocation];
                    }
                    postDetailViewController.post.geolocation = nil;
                    postDetailViewController.hasLocation.enabled = NO;
                    [postDetailViewController refreshButtons];
                    break;
            }
            [tableView reloadData];
            break;
	}
    [aTableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:YES];
}

- (void)featuredImageUploadFailed: (NSNotification *)notificationInfo {
    isUploadingFeaturedImage = NO;
    [featuredImageTableViewCell setSelectionStyle:UITableViewCellSelectionStyleNone];
    [featuredImageSpinner stopAnimating];
    [featuredImageSpinner setHidden:YES];
    [featuredImageView setHidden:NO];
    [tableView reloadData];
    //The code that shows the error message is available in the failure block in PostMediaViewController.
}

- (void)featuredImageUploadSucceeded: (NSNotification *)notificationInfo {
    isUploadingFeaturedImage = NO;
    Media *media = (Media *)[notificationInfo object];
    if (media) {
        [featuredImageTableViewCell setSelectionStyle:UITableViewCellSelectionStyleNone];
        [featuredImageSpinner stopAnimating];
        [featuredImageSpinner setHidden:YES];
        [featuredImageLabel setHidden:YES];
        [featuredImageView setHidden:NO];
        self.postDetailViewController.post.post_thumbnail = media.mediaID;
        [featuredImageView setImage:[UIImage imageWithContentsOfFile:media.localURL]];
    } else {
        //reset buttons
    }
    [postDetailViewController refreshButtons];
    [tableView reloadData];
}

- (void)showFeaturedImageUploader:(NSNotification *)notificationInfo {
    isUploadingFeaturedImage = YES;
    [featuredImageView setHidden:YES];
    [featuredImageLabel setHidden:NO];
    [featuredImageLabel setText:NSLocalizedString(@"Uploading Image", @"Uploading a featured image in post settings")];
    [featuredImageSpinner setHidden:NO];
    if (!featuredImageSpinner.isAnimating)
        [featuredImageSpinner startAnimating];
    [tableView reloadData];
}

#pragma mark -
#pragma mark UIActionSheetDelegate
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        [featuredImageTableViewCell setSelectionStyle:UITableViewCellSelectionStyleBlue];
        postDetailViewController.post.post_thumbnail = nil;
        [postDetailViewController refreshButtons];
        [tableView reloadData];
    }
    
}

#pragma mark -
#pragma mark UIPickerViewDataSource

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)aPickerView numberOfRowsInComponent:(NSInteger)component {
    if (aPickerView.tag == TAG_PICKER_STATUS) {
        return [statusList count];
    } else if (aPickerView.tag == TAG_PICKER_VISIBILITY) {
        return [visibilityList count];
    } else if (aPickerView.tag == TAG_PICKER_FORMAT) {
        return [formatsList count];
    }
    return 0;
}

#pragma mark -
#pragma mark UIPickerViewDelegate

- (NSString *)pickerView:(UIPickerView *)aPickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    if (aPickerView.tag == TAG_PICKER_STATUS) {
        return [statusList objectAtIndex:row];
    } else if (aPickerView.tag == TAG_PICKER_VISIBILITY) {
        return [visibilityList objectAtIndex:row];
    } else if (aPickerView.tag == TAG_PICKER_FORMAT) {
        return [formatsList objectAtIndex:row];
    }

    return @"";
}

- (void)pickerView:(UIPickerView *)aPickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    if (aPickerView.tag == TAG_PICKER_STATUS) {
        postDetailViewController.apost.statusTitle = [statusList objectAtIndex:row];
    } else if (aPickerView.tag == TAG_PICKER_VISIBILITY) {
        NSString *visibility = [visibilityList objectAtIndex:row];
        if ([visibility isEqualToString:NSLocalizedString(@"Private", @"Post privacy status in the Post Editor/Settings area (compare with WP core translations).")]) {
            postDetailViewController.apost.status = @"private";
            postDetailViewController.apost.password = nil;
        } else {
            if ([postDetailViewController.apost.status isEqualToString:@"private"]) {
                postDetailViewController.apost.status = @"publish";
            }
            if ([visibility isEqualToString:NSLocalizedString(@"Password protected", @"Post password protection in the Post Editor/Settings area (compare with WP core translations).")]) {
                postDetailViewController.apost.password = @"";
            } else {
                postDetailViewController.apost.password = nil;
            }
        }
    } else if (aPickerView.tag == TAG_PICKER_FORMAT) {
        postDetailViewController.post.postFormatText = [formatsList objectAtIndex:row];
    }
	[postDetailViewController refreshButtons];
    [tableView reloadData];
}


#pragma mark -
#pragma mark Pickers and keyboard animations

- (void)showPicker:(UIView *)picker {
    if (isShowingKeyboard)
        [passwordTextField resignFirstResponder];

    if (IS_IPAD) {
        
        UIViewController *fakeController = [[UIViewController alloc] init];
        if (picker.tag == TAG_PICKER_DATE) {
            fakeController.contentSizeForViewInPopover = CGSizeMake(320.0f, 256.0f);

            UISegmentedControl *publishNowButton = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObject:NSLocalizedString(@"Publish Immediately", @"Post publishing status in the Post Editor/Settings area (compare with WP core translations).")]];
            publishNowButton.momentary = YES; 
            publishNowButton.frame = CGRectMake(0.0f, 0.0f, 320.0f, 40.0f);
            publishNowButton.segmentedControlStyle = UISegmentedControlStyleBar;
            if ([publishNowButton respondsToSelector:@selector(setTintColor:)]) {
                publishNowButton.tintColor = postDetailViewController.toolbar.tintColor;
            }
            [publishNowButton addTarget:self action:@selector(removeDate) forControlEvents:UIControlEventValueChanged];
            [fakeController.view addSubview:publishNowButton];
            CGRect frame = picker.frame;
            frame.origin.y = 40.0f;
            picker.frame = frame;
        } else {
            fakeController.contentSizeForViewInPopover = CGSizeMake(320.0f, 216.0f);
        }
        
        [fakeController.view addSubview:picker];
        popover = [[UIPopoverController alloc] initWithContentViewController:fakeController];
        if ([popover respondsToSelector:@selector(popoverBackgroundViewClass)]) {
            popover.popoverBackgroundViewClass = [WPPopoverBackgroundView class];
        }
        
        CGRect popoverRect;
        if (picker.tag == TAG_PICKER_STATUS)
            popoverRect = [self.view convertRect:statusLabel.frame fromView:[statusLabel superview]];
        else if (picker.tag == TAG_PICKER_VISIBILITY)
            popoverRect = [self.view convertRect:visibilityLabel.frame fromView:[visibilityLabel superview]];
        else if (picker.tag == TAG_PICKER_FORMAT)
            popoverRect = [self.view convertRect:postFormatLabel.frame fromView:[postFormatLabel superview]];
        else 
            popoverRect = [self.view convertRect:publishOnDateLabel.frame fromView:[publishOnDateLabel superview]];

        popoverRect.size.width = 100.0f;
        [popover presentPopoverFromRect:popoverRect inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
        
    } else {
    
        CGFloat width = postDetailViewController.view.frame.size.width;
        CGFloat height = 0.0;
        
        // TODO: Refactor this class to not use UIActionSheets for display.
        // <rant>Shoehorning a UIPicker inside a UIActionSheet is just madness.</rant>
        // For now, hardcoding height values for the iPhone so we don't get
        // a funky gap at the bottom of the screen on the iPhone 5.
        if(postDetailViewController.view.frame.size.height <= 416.0f) {
            height = 490.0f;
        } else {
            height = 500.0f;
        }
        if(UIInterfaceOrientationIsLandscape(self.interfaceOrientation)){
            height = 460.0f; // Show most of the actionsheet but keep the top of the view visible.
        }
        
        UIView *pickerWrapperView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, width, 260.0f)]; // 216 + 44 (height of the picker and the "tooblar")
        pickerWrapperView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
        [pickerWrapperView addSubview:picker];
                
        CGRect pickerFrame = picker.frame;
        pickerFrame.size.width = width;
        picker.frame = pickerFrame;
        
        actionSheet = [[UIActionSheet alloc] initWithTitle:nil delegate:nil cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
        [actionSheet setActionSheetStyle:UIActionSheetStyleAutomatic];
        [actionSheet setBounds:CGRectMake(0.0f, 0.0f, width, height)];
        
        [actionSheet addSubview:pickerWrapperView];

        UISegmentedControl *closeButton = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObject:NSLocalizedString(@"Done", @"Default main action button for closing/finishing a work flow in the app (used in Comments>Edit, Comment edits and replies, post editor body text, etc, to dismiss keyboard).")]];
        closeButton.momentary = YES;
        CGFloat x = self.view.frame.size.width - 60.0f;
        closeButton.frame = CGRectMake(x, 7.0f, 50.0f, 30.0f);
        closeButton.segmentedControlStyle = UISegmentedControlStyleBar;
        if ([closeButton respondsToSelector:@selector(setTintColor:)]) {
            closeButton.tintColor = [UIColor blackColor];
        }
        [closeButton addTarget:self action:@selector(hidePicker) forControlEvents:UIControlEventValueChanged];
        closeButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        [pickerWrapperView addSubview:closeButton];
        
        UISegmentedControl *publishNowButton = nil;
        if (picker.tag == TAG_PICKER_DATE) {
            publishNowButton = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObject:NSLocalizedString(@"Publish Immediately", @"Post publishing status in the Post Editor/Settings area (compare with WP core translations).")]];
            publishNowButton.momentary = YES; 
            publishNowButton.frame = CGRectMake(10.0f, 7.0f, 129.0f, 30.0f);
            publishNowButton.segmentedControlStyle = UISegmentedControlStyleBar;
            if ([publishNowButton respondsToSelector:@selector(setTintColor:)]) {
                publishNowButton.tintColor = [UIColor blackColor];
            }
            [publishNowButton addTarget:self action:@selector(removeDate) forControlEvents:UIControlEventValueChanged];
            [pickerWrapperView addSubview:publishNowButton];
        }
        
        if ([[UISegmentedControl class] respondsToSelector:@selector(appearance)]) {
            // Since we're requiring a black tint we do not want to use the custom text colors.
            NSDictionary *titleTextAttributesForStateNormal = [NSDictionary dictionaryWithObjectsAndKeys:
                                                               [UIColor whiteColor],
                                                               UITextAttributeTextColor, 
                                                               [UIColor darkGrayColor],
                                                               UITextAttributeTextShadowColor,  
                                                               [NSValue valueWithUIOffset:UIOffsetMake(0, 1)], 
                                                               UITextAttributeTextShadowOffset,
                                                               nil];
            
            // The UISegmentControl does not show a pressed state for its button so (for now) use the same
            // state for normal and highlighted.
            // TODO: It would be nice to refactor this to use a toolbar and buttons instead of a segmented control to get the 
            // correct look and feel.
            [closeButton setTitleTextAttributes:titleTextAttributesForStateNormal forState:UIControlStateNormal];
            [closeButton setTitleTextAttributes:titleTextAttributesForStateNormal forState:UIControlStateHighlighted];
            
            if (publishNowButton) {
                [publishNowButton setTitleTextAttributes:titleTextAttributesForStateNormal forState:UIControlStateNormal];
                [publishNowButton setTitleTextAttributes:titleTextAttributesForStateNormal forState:UIControlStateHighlighted];
            }
        }
        
        [actionSheet showInView:postDetailViewController.view];
        [actionSheet setBounds:CGRectMake(0.0f, 0.0f, width, height)]; // Update the bounds again now that its in the view else it won't draw correctly.
    }
}

- (void)hidePicker {
    [actionSheet dismissWithClickedButtonIndex:0 animated:YES];
     actionSheet = nil;
}

- (void)removeDate {
    datePickerView.date = [NSDate date];
    postDetailViewController.apost.dateCreated = nil;
    [tableView reloadData];
    if (IS_IPAD)
        [popover dismissPopoverAnimated:YES];
    else
        [self hidePicker];

}

- (void)keyboardWillShow:(NSNotification *)keyboardInfo {
    isShowingKeyboard = YES;
}

- (void)keyboardWillHide:(NSNotification *)keyboardInfo {
    isShowingKeyboard = NO;
}

#pragma mark -
#pragma mark CLLocationManagerDelegate

// Delegate method from the CLLocationManagerDelegate protocol.
- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
		   fromLocation:(CLLocation *)oldLocation {
	// If it's a relatively recent event, turn off updates to save power
    NSDate* eventDate = newLocation.timestamp;
    NSTimeInterval howRecent = [eventDate timeIntervalSinceNow];
    if (abs(howRecent) < 15.0)
    {
		if (!isUpdatingLocation) {
			return;
		}
		isUpdatingLocation = NO;
		CLLocationCoordinate2D coordinate = newLocation.coordinate;
#if FALSE // Switch this on/off for testing location updates
		// Factor values (YMMV)
		// 0.0001 ~> whithin your zip code (for testing small map changes)
		// 0.01 ~> nearby cities (good for testing address label changes)
		double factor = 0.001f; 
		coordinate.latitude += factor * (rand() % 100);
		coordinate.longitude += factor * (rand() % 100);
#endif
		Coordinate *c = [[Coordinate alloc] initWithCoordinate:coordinate];
		postDetailViewController.post.geolocation = c;
		postDetailViewController.hasLocation.enabled = YES;
        WPLog(@"Added geotag (%+.6f, %+.6f)",
			  c.latitude,
			  c.longitude);
		[locationManager stopUpdatingLocation];
        [postDetailViewController refreshButtons];
		[tableView reloadData];
		
		[self geocodeCoordinate:c.coordinate];

    }
    // else skip the event and process the next one.
}

#pragma mark - CLGecocoder wrapper

- (void)geocodeCoordinate:(CLLocationCoordinate2D)c {
	if (reverseGeocoder) {
		if (reverseGeocoder.geocoding)
			[reverseGeocoder cancelGeocode];
	}
    reverseGeocoder = [[CLGeocoder alloc] init];
    [reverseGeocoder reverseGeocodeLocation:[[CLLocation alloc] initWithLatitude:c.latitude longitude:c.longitude] completionHandler:^(NSArray *placemarks, NSError *error) {
        if (placemarks) {
            CLPlacemark *placemark = [placemarks objectAtIndex:0];
            if (placemark.subLocality) {
                address = [NSString stringWithFormat:@"%@, %@, %@", placemark.subLocality, placemark.locality, placemark.country];
            } else {
                address = [NSString stringWithFormat:@"%@, %@, %@", placemark.locality, placemark.administrativeArea, placemark.country];
            }
            addressLabel.text = address;
        } else {
            NSLog(@"Reverse geocoder failed for coordinate (%.6f, %.6f): %@",
                  c.latitude,
                  c.longitude,
                  [error localizedDescription]);
            
            address = [NSString stringWithString:NSLocalizedString(@"Location unknown", @"Used when geo-tagging posts, if the geo-tagging failed.")];
            addressLabel.text = address;
        }
    }];
}

@end
