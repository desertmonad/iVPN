
/*
 
 Copyright (c) 2008, Alex Jones
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without modification, are permitted provided that
 the following conditions are met:
 
	1.	Redistributions of source code must retain the above copyright notice, this list of conditions and the
		following disclaimer.
 
	2.	Redistributions in binary form must reproduce the above copyright notice, this list of conditions and
		the following disclaimer in the documentation and/or other materials provided with the distribution.
 
	3.	Neither the name of MacServe nor the names of its contributors may be used to endorse
		or promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
 COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
 TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 */

#import <Cocoa/Cocoa.h>
#import <AGProcess.h>
#import <Security/Security.h>
#import <SystemConfiguration/SystemConfiguration.h>



@interface MSController : NSObject {
	
	IBOutlet NSMenuItem *startServerMenu;
	IBOutlet NSMenuItem *stopServerMenu;
	IBOutlet NSSegmentedControl *toggleServer;
	IBOutlet NSTextField *serverStatus;
	IBOutlet NSTextField *startAddress;
	IBOutlet NSTextField *endAddress;
	IBOutlet NSTextField *routerAddress;
	IBOutlet NSTextField *subnetMask;
	IBOutlet NSTextField *primaryDNS;
	IBOutlet NSTextField *secondaryDNS;
	IBOutlet NSTextField *userName;
	IBOutlet NSTextField *passWord;
	IBOutlet NSProgressIndicator *progIndicator;
	IBOutlet NSButton *startupCheckbox;
	IBOutlet NSButton *l2tpType;
	IBOutlet NSButton *pptpType;
	IBOutlet NSSecureTextField *sharedSecret;
	IBOutlet NSButton *useKeychain;
	IBOutlet NSTextField *testWarn;
	
	NSEnumerator *processEnumerator;
	AGProcess *process;
	NSTimer *timer;
	AuthorizationRef myAuthorizationRef;
	OSStatus err;
	
}

- (IBAction)startServerMenu:(id)sender;
- (IBAction)stopServerMenu:(id)sender;
- (IBAction)toggleServer:(id)sender;
- (IBAction)toggleL2TP:(id)sender;
- (IBAction)useKeychain:(id)sender;
- (IBAction)getHelp:(id)sender;
- (IBAction)checkForUpdate:(id)sender;
- (IBAction)startupItem:(id)sender;

- (void)loadUser;
- (void)loadConf;
- (void)saveUser;
- (void)saveConf;
- (void)saveKeychain;
- (void)loadKeychain;
- (void)saveStartupItem;
- (void)deleteStartupItem;
- (void)periodicChecker:(NSTimer*)timer;
- (int)checkStatus;
- (void)setStatusStarted;
- (void)setStatusStopped;
- (void)checkUpdate:(bool)yes;
- (int)checkFields;

@end
