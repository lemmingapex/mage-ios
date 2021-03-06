//
//  LoginViewController.m
//  Mage
//
//

#import "LoginViewController.h"
#import "LocalAuthentication.h"
#import "User+helper.h"
#import <Observation+helper.h>

#import <Location+helper.h>
#import <Layer+helper.h>
#import <Form.h>
#import <Mage.h>
#import "AppDelegate.h"
#import <HttpManager.h>
#import "MageRootViewController.h"
#import <UserUtility.h>
#import "DeviceUUID.h"
#import "MageServer.h"
#import "Observations.h"
#import "MagicalRecord+delete.h"

@interface LoginViewController ()

    @property (weak, nonatomic) IBOutlet UITextField *usernameField;
    @property (weak, nonatomic) IBOutlet UITextField *passwordField;
    @property (weak, nonatomic) IBOutlet UITextField *serverUrlField;
    @property (weak, nonatomic) IBOutlet UIActivityIndicatorView *loginIndicator;
    @property (weak, nonatomic) IBOutlet UIButton *loginButton;
    @property (weak, nonatomic) IBOutlet UIButton *lockButton;
    @property (weak, nonatomic) IBOutlet UISwitch *showPassword;
    @property (weak, nonatomic) IBOutlet UITextView *loginStatus;
    @property (weak, nonatomic) IBOutlet UIButton *statusButton;
    @property (weak, nonatomic) IBOutlet UILabel *versionLabel;
    @property (weak, nonatomic) IBOutlet UIActivityIndicatorView *serverVerificationIndicator;

    @property (strong, nonatomic) MageServer *server;
    @property (nonatomic) BOOL allowLogin;
@end

@implementation LoginViewController

- (void) authenticationWasSuccessful {
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if ([defaults objectForKey:@"showDisclaimer"] == nil || ![[defaults objectForKey:@"showDisclaimer"] boolValue]) {
        [[UserUtility singleton ] acceptConsent];
        [self performSegueWithIdentifier:@"SkipDisclaimerSegue" sender:nil];
    } else {
        [self performSegueWithIdentifier:@"LoginSegue" sender:nil];
    }
    self.usernameField.textColor = [UIColor blackColor];
    self.passwordField.textColor = [UIColor blackColor];
    self.loginStatus.hidden = YES;
    self.statusButton.hidden = YES;
    
    [self resetLogin];
}

- (void) authenticationHadFailure {
    self.statusButton.hidden = NO;
    self.loginStatus.hidden = NO;
    self.loginStatus.text = @"The username or password you entered is incorrect";
    self.usernameField.textColor = [[UIColor redColor] colorWithAlphaComponent:.65f];
    self.passwordField.textColor = [[UIColor redColor] colorWithAlphaComponent:.65f];

    [self resetLogin];
}

- (void) registrationWasSuccessful {
    UIAlertView *alert = [[UIAlertView alloc]
                          initWithTitle:@"Registration Sent"
                          message:@"Your device has been registered.  \nAn administrator has been notified to approve this device."
                          delegate:nil
                          cancelButtonTitle:@"OK"
                          otherButtonTitles:nil];
	
	[alert show];
    [self resetLogin];
}

- (void) resetLogin {
    [self.loginButton setEnabled:YES];
    [self.loginIndicator stopAnimating];
    [self.usernameField setEnabled:YES];
    [self.usernameField setBackgroundColor:[UIColor whiteColor]];
    [self.passwordField setEnabled:YES];
    [self.passwordField setBackgroundColor:[UIColor whiteColor]];
    [self.serverUrlField setEnabled:YES];
    [self.serverUrlField setBackgroundColor:[UIColor whiteColor]];
    [self.lockButton setEnabled:YES];
    [self.showPassword setEnabled:YES];
}

- (void) startLogin {
    [self.loginButton setEnabled:NO];
    [self.loginIndicator startAnimating];
    [self.usernameField setEnabled:NO];
    [self.usernameField setBackgroundColor:[UIColor lightGrayColor]];
    [self.passwordField setEnabled:NO];
    [self.passwordField setBackgroundColor:[UIColor lightGrayColor]];
    [self.serverUrlField setEnabled:NO];
    [self.serverUrlField setBackgroundColor:[UIColor lightGrayColor]];
    [self.lockButton setEnabled:NO];
    [self.showPassword setEnabled:NO];
}

- (void) verifyLogin {
    if (!self.allowLogin) return;
    if (self.server.reachabilityManager.reachable && ([self usernameChanged] || [self serverUrlChanged])) {
        [MagicalRecord deleteCoreDataStack];
        [MagicalRecord setupCoreDataStackWithStoreNamed:@"Mage.sqlite"];
    }
    
	// setup authentication
    [self startLogin];
    NSUUID *deviceUUID = [DeviceUUID retrieveDeviceUUID];
	NSString *uidString = deviceUUID.UUIDString;
    NSLog(@"uid: %@", uidString);
	NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
														 _usernameField.text, @"username",
														 _passwordField.text, @"password",
														 uidString, @"uid",
														 nil];
	
	[self.server.authentication loginWithParameters: parameters];
}

- (BOOL) usernameChanged {
    NSDictionary *loginParameters = [self.server.authentication loginParameters];
    NSString *username = [loginParameters objectForKey:@"username"];
    return [username length] != 0 && ![self.usernameField.text isEqualToString:username];
}

- (BOOL) serverUrlChanged {
    NSDictionary *loginParameters = [self.server.authentication loginParameters];
    NSString *serverUrl = [loginParameters objectForKey:@"serverUrl"];
    return [serverUrl length] != 0 && ![self.serverUrlField.text isEqualToString:serverUrl];
}

- (BOOL) changeTextViewFocus: (id)sender {
    if ([[_usernameField text] isEqualToString:@""]) {
        [_usernameField becomeFirstResponder];
		return YES;
    } else if ([[_passwordField text] isEqualToString:@""]) {
        [_passwordField becomeFirstResponder];
		return YES;
    } else {
		return NO;
	}
}

- (IBAction)toggleUrlField:(id)sender {
    if (self.serverUrlField.enabled) {
		NSURL *url = [NSURL URLWithString:self.serverUrlField.text];
        [self initMageServerWithURL:url];
    } else {
        [self.usernameField setEnabled:NO];
        [self.passwordField setEnabled:NO];
        [self.serverUrlField setEnabled:YES];
        [self.lockButton setImage:[UIImage imageNamed:@"unlock.png"] forState:UIControlStateNormal];
    }
}

//  When we are done editing on the keyboard
- (IBAction)resignAndLogin:(id) sender {
    if (![self changeTextViewFocus: sender]) {
		[sender resignFirstResponder];
		[self verifyLogin];
	}
}

- (IBAction)loginButtonPress:(id)sender {
    if (![self changeTextViewFocus: sender]) {
        [sender resignFirstResponder];
        if ([_usernameField isFirstResponder]) {
            [_usernameField resignFirstResponder];
        } else if([_passwordField isFirstResponder]) {
            [_passwordField resignFirstResponder];
        }
        
        [self verifyLogin];
    }

}

//  When the view reappears after logout we want to wipe the username and password fields
- (void)viewWillAppear:(BOOL)animated {
    
    NSString *versionString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    NSString *buildString = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    [self.versionLabel setText:[NSString stringWithFormat:@"v%@ b%@", versionString, buildString]];
    
    [self.usernameField setText:@""];
    [self.passwordField setText:@""];
    [self.passwordField setDelegate:self];
    
}

- (void) viewDidAppear:(BOOL)animated {
    NSURL *url = [MageServer baseURL];
    if ([@"" isEqualToString:url.absoluteString]) {
        [self toggleUrlField:NULL];
        [self.serverUrlField becomeFirstResponder];
        return;
    } else {
        [self.serverUrlField setText:[url absoluteString]];
        [self initMageServerWithURL:url];
        
        self.allowLogin = YES;
    }
}

- (void) viewDidLoad {
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc]
                                   initWithTarget:self
                                   action:@selector(dismissKeyboard)];
    
    [self.view addGestureRecognizer:tap];
}

- (void) initMageServerWithURL:(NSURL *) url {
    [self.serverVerificationIndicator startAnimating];
    [self.lockButton setHidden:YES];
    __weak __typeof__(self) weakSelf = self;
    [MageServer serverWithURL:url authenticationDelegate:self success:^(MageServer *mageServer) {
        weakSelf.server = mageServer;
        
        [weakSelf.serverUrlField setEnabled:NO];
        [weakSelf.lockButton setImage:[UIImage imageNamed:@"lock.png"] forState:UIControlStateNormal];
        
        weakSelf.loginStatus.hidden = YES;
        weakSelf.statusButton.hidden = YES;
        [weakSelf.usernameField setEnabled:YES];
        [weakSelf.passwordField setEnabled:YES];
        weakSelf.serverUrlField.textColor = [UIColor blackColor];
        [weakSelf.lockButton setHidden:NO];
        [weakSelf.serverVerificationIndicator stopAnimating];
        weakSelf.allowLogin = YES;
    } failure:^(NSError *error) {
        weakSelf.allowLogin = NO;
        weakSelf.loginStatus.hidden = NO;
        weakSelf.statusButton.hidden = NO;
        weakSelf.loginStatus.text = error.localizedDescription;
        weakSelf.serverUrlField.textColor = [[UIColor redColor] colorWithAlphaComponent:.65f];
        [weakSelf.lockButton setHidden:NO];
        [weakSelf.serverVerificationIndicator stopAnimating];
    }];
}

-(void)dismissKeyboard {
    [self.view endEditing:YES];
}

- (IBAction)showPasswordSwitchAction:(id)sender {
    [self.passwordField setSecureTextEntry:!self.passwordField.secureTextEntry];
    self.passwordField.clearsOnBeginEditing = NO;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *updatedString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    
	// if we override this we need to check if its \n
	if ([string isEqualToString:@"\n"]) {
		[textField resignFirstResponder];
	} else {
		textField.text = updatedString;
	}
    
    return NO;
}

- (BOOL) textFieldShouldReturn:(UITextField *) textField {
	return YES;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

@end
