//
//  SMTPSenderAppDelegate.m
//  SMTPSender
//
//  Created by Ian Baird on 10/28/2008.
//
//  Copyright (c) 2008 Skorpiostech, Inc. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//

#import "SMTPSenderAppDelegate.h"
#import "NSData+Base64Additions.h"

@implementation SMTPSenderAppDelegate

+ (void)initialize {
    NSDictionary *settings = @{
		@"fromEmail": @"me@example.com",
		@"toEmail": @"you@example.com",
		@"relayHost": @"smtp.example.com",
		@"login": @"me@example.com",
		@"pass": @"SekritSquirrel",
		@"requiresAuth": @YES,
		@"wantsSecure": @YES
	};
	[[NSUserDefaults standardUserDefaults] registerDefaults:settings];
}

- (void)applicationDidFinishLaunching:(UIApplication *)application {    
    // Override point for customization after app launch
    [_window makeKeyAndVisible];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    [[NSUserDefaults standardUserDefaults] synchronize];
    [self updateTextView];
}

- (void)dealloc {
    [_window release];
    [super dealloc];
}

- (void)updateTextView {
    NSMutableString *logText = [[NSMutableString alloc] init];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [logText appendString:@"Use the iOS Settings app to change the values below.\n\n"];
    [logText appendFormat:@"From: %@\n", [defaults objectForKey:@"fromEmail"]];
    [logText appendFormat:@"To: %@\n", [defaults objectForKey:@"toEmail"]];
    [logText appendFormat:@"Host: %@\n", [defaults objectForKey:@"relayHost"]];
    [logText appendFormat:@"Auth: %@\n", ([[defaults objectForKey:@"requiresAuth"] boolValue] ? @"On" : @"Off")];
    
    if ([[defaults objectForKey:@"requiresAuth"] boolValue]) {
        [logText appendFormat:@"Login: %@\n", [defaults objectForKey:@"login"]];
        [logText appendFormat:@"Password: %@\n", [defaults objectForKey:@"pass"]];
    }
    [logText appendFormat:@"Secure: %@\n", [[defaults objectForKey:@"wantsSecure"] boolValue] ? @"Yes" : @"No"];
    self.textView.text = logText;
    [logText release];
}

- (IBAction)sendMessage:(id)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    SKPSMTPMessage *testMsg = [[SKPSMTPMessage alloc] init];

    testMsg.fromEmail = [defaults objectForKey:@"fromEmail"];
    testMsg.toEmail = [defaults objectForKey:@"toEmail"];
    testMsg.bccEmail = [defaults objectForKey:@"bccEmal"];

    testMsg.relayHost = [defaults objectForKey:@"relayHost"];
    testMsg.requiresAuth = [[defaults objectForKey:@"requiresAuth"] boolValue];

    if (testMsg.requiresAuth) {
        testMsg.login = [defaults objectForKey:@"login"];
        testMsg.pass = [defaults objectForKey:@"pass"];
    }
    
    testMsg.wantsSecure = [[defaults objectForKey:@"wantsSecure"] boolValue]; // smtp.gmail.com doesn't work without TLS!

    testMsg.subject = @"SMTPMessage Test Message";

    // Only do this for self-signed certs!
    //testMsg.validateSSLChain = NO;

    testMsg.delegate = self;
    
    NSDictionary *plainPart = @{
		kSKPSMTPPartContentTypeKey: @"text/plain",
		kSKPSMTPPartContentTransferEncodingKey: @"8bit",
		kSKPSMTPPartMessageKey: @"This is a tést messåge."
	};
    
    NSString *vcfPath = [[NSBundle mainBundle] pathForResource:@"test" ofType:@"vcf"];
    NSData *vcfData = [NSData dataWithContentsOfFile:vcfPath];
    
    NSDictionary *vcfPart = @{
		kSKPSMTPPartContentDispositionKey: @"attachment;\r\n\tfilename=\"test.vcf\"",
		kSKPSMTPPartContentTypeKey: @"text/directory;\r\n\tx-unix-mode=0644;\r\n\tname=\"test.vcf\"",
		kSKPSMTPPartContentTransferEncodingKey: @"base64",
		kSKPSMTPPartMessageKey: [vcfData encodeBase64ForData],
	};
    
    testMsg.parts = @[plainPart, vcfPart];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [testMsg send];
    });
}

- (void)messageSent:(SKPSMTPMessage *)message
{
    [message release];
    self.textView.text  = @"Yay! Message was sent!";
    //NSLog(@"delegate - message sent");
}

- (void)messageFailed:(SKPSMTPMessage *)message error:(NSError *)error
{
	if ([NSThread isMainThread]) {
		//self.textView.text = [NSString stringWithFormat:@"Darn! Error: %@, %@", [error code], [error localizedDescription]];
		self.textView.text = [NSString stringWithFormat:@"Darn! Error!\n%i: %@\n%@", [error code], [error localizedDescription], [error localizedRecoverySuggestion]];
		[message release];
		
		//NSLog(@"delegate - error(%d): %@", [error code], [error localizedDescription]);
	} else {
		dispatch_sync(dispatch_get_main_queue(), ^{
			[self messageFailed:message error:error];
		});
	}
}

@end
