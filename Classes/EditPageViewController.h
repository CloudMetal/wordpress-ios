//
//  EditPageViewController.h
//  WordPress
//
//  Created by Chris Boyd on 9/4/10.
//

#import <UIKit/UIKit.h>
#import "WordPressAppDelegate.h"
#import "BlogDataManager.h"
#import "Post.h"
#import "Media.h"
#import "UITextViewCell.h"
#import "UITextFieldCell.h"
#import "PageViewController.h"
#import "ManagedObjectCloner.h"
#import "WPProgressHUD.h"

@class DraftManager, PageManager;

@interface EditPageViewController : UIViewController <UITableViewDelegate, UIPickerViewDelegate, UIPickerViewDataSource, UIActionSheetDelegate, UITextFieldDelegate, UITextViewDelegate> {
	IBOutlet UITableView *table;	
	IBOutlet UIActionSheet *actionSheet;
	IBOutlet UITextView *contentTextView;
	IBOutlet UITextField *titleTextField;
	IBOutlet UIButton *resignTextFieldButton;
	IBOutlet UIPopoverController *statusPopover;
	IBOutlet WPProgressHUD *spinner;
	
	BOOL isShowingKeyboard, isLocalDraft;
	CGRect normalTableFrame;
	NSNumber *selectedSection;
	NSString *originalTitle, *originalStatus, *originalContent;
	NSMutableDictionary *statuses;
	UIViewController *pickerViewController;
	
	NSURLConnection *connection;
	NSURLRequest *urlRequest;
	NSURLResponse *urlResponse;
	NSMutableData *payload;
	
	id<PageViewControllerProtocol> delegate;
	BlogDataManager *dm;
	WordPressAppDelegate *appDelegate;
	PageViewController *pageDetailView;
	Post *page;
}

@property (nonatomic, retain) IBOutlet UITableView *table;
@property (nonatomic, retain) IBOutlet UIActionSheet *actionSheet;
@property (nonatomic, retain) IBOutlet UITextView *contentTextView;
@property (nonatomic, retain) IBOutlet UITextField *titleTextField;
@property (nonatomic, retain) IBOutlet UIButton *resignTextFieldButton;
@property (nonatomic, retain) IBOutlet WPProgressHUD *spinner;
@property (nonatomic, retain) IBOutlet UIPopoverController *statusPopover;
@property (nonatomic, assign) BOOL isShowingKeyboard, isLocalDraft;
@property (nonatomic, assign) CGRect normalTableFrame;
@property (nonatomic, assign) NSNumber *selectedSection;
@property (nonatomic, retain) NSString *originalTitle, *originalStatus, *originalContent;
@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, retain) NSURLRequest *urlRequest;
@property (nonatomic, retain) NSURLResponse *urlResponse;
@property (nonatomic, retain) NSMutableData *payload;
@property (nonatomic, retain) NSMutableDictionary *statuses;
@property (nonatomic, retain) UIViewController *pickerViewController;
@property (nonatomic, assign) id <PageViewControllerProtocol> delegate;
@property (nonatomic, assign) BlogDataManager *dm;
@property (nonatomic, assign) WordPressAppDelegate *appDelegate;
@property (nonatomic, assign) PageViewController *pageDetailView;
@property (nonatomic, retain) Post *page;

- (void)setupPage;
- (void)refreshTable;
- (void)refreshButtons;
- (void)refreshPage;
- (IBAction)showStatusPicker:(id)sender;
- (IBAction)hideStatusPicker:(id)sender;
- (IBAction)showStatusPopover:(id)sender;
- (IBAction)resignTextField:(id)sender;
- (NSInteger)indexForStatus:(NSString *)status;
- (void)hideKeyboard:(NSNotification *)notification;
- (void)keyboardWillShow:(NSNotification *)notification;
- (void)keyboardWillHide:(NSNotification *)notification;
- (void)save;
- (void)publish;
- (BOOL)hasChanges;
- (void)checkPublishable;
- (void)insertMediaAbove:(NSNotification *)notification;
- (void)insertMediaBelow:(NSNotification *)notification;

// Recovery
- (void)preserveUnsavedPage;
- (void)clearUnsavedPage;
- (void)restoreUnsavedPage;

@end