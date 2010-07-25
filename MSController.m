
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

#import "MSController.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>


@implementation MSController

NSString * const processName = @"vpnd";

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	
	[ self loadUser ];
	[ self loadConf ];
	if([ l2tpType state ] == 1) {
		if([ useKeychain state ] == 1) {
			[ testWarn setHidden: NO ];
			[ self loadKeychain ];
		}
	}
	
	NSFileManager *fileManager = [ NSFileManager defaultManager ];
	
	if([ fileManager fileExistsAtPath:@"/Library/StartupItems/iVPN/iVPN" ] == YES) {
		[ startupCheckbox setState:1 ];
	}
	
	timer = [ NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(periodicChecker:) userInfo:nil repeats:YES ];
	[[ NSRunLoop currentRunLoop ] addTimer:timer forMode:NSDefaultRunLoopMode ];
	
	err = AuthorizationCreate (NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &myAuthorizationRef);
	
}

- (void)awakeFromNib {
	
	NSUserDefaults *defaults = [ NSUserDefaults standardUserDefaults ];
	
	if([ defaults boolForKey: @"donated" ] == NO) {

		int donation = NSRunAlertPanel(@"Plaese Donate", [ NSString stringWithFormat:@"Thank you for using iVPN.  If you find this app useful, please make a donation." ], @"Donate", @"Ignore", @"Already Donated");
		
		if(donation == 1) {
			[[ NSWorkspace sharedWorkspace ] openURL:[NSURL URLWithString:@"http://www.macserve.org.uk/projects/ivpn/" ]];
		}
		if(donation == -1) {
			
			[ defaults setBool: YES forKey: @"donated" ];
		}
	
	}
		
	[ self checkUpdate: FALSE ];

}

- (IBAction)startServerMenu:(id)sender {
	
	[ self setStatusStarted ];
	[ self toggleServer:startServerMenu ];
	
}

- (IBAction)stopServerMenu:(id)sender {
	
	[ self setStatusStopped ];
	[ self toggleServer:startServerMenu ];
	
}

- (IBAction)toggleServer:(id)sender {
	
	if([ toggleServer selectedSegment ] == 0) {

		[ progIndicator startAnimation:progIndicator ];
		
		if([ self checkFields ] == 1) {
			return;
		}
		
		[ self saveUser ];
		[ self saveConf ];
		if([ l2tpType state ] == 1) {
			if([ useKeychain state ] == 1) {
				[ self saveKeychain ];
			}
		}
		
		NSTask *vpndTask = [[ NSTask alloc ] init ];
		[ vpndTask setLaunchPath: @"/usr/sbin/vpnd" ];
		[ vpndTask launch ];
		
		char *sysctlArgs[3];
		sysctlArgs[0] = "-w";
		sysctlArgs[1] = "net.inet.ip.forwarding=1";
		sysctlArgs[2] = NULL;
		
		err = AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/usr/sbin/sysctl", 0, sysctlArgs, NULL);
		
		NSLog(@"Started Server");
		
		if([ startupCheckbox state ] == 1) {
			[ self saveStartupItem ];
		}
		
	}
	else {
		
		[ progIndicator startAnimation:progIndicator ];
		
		NSAppleScript *script = [[ NSAppleScript alloc ] initWithSource:@"do shell script \"killall vpnd | sudo sysctl -w net.inet.ip.forwarding=0\" with administrator privileges" ];
		
		NSDictionary *errorInfo;
		[ script executeAndReturnError:&errorInfo ];
		
		NSLog(@"Server stopped");
		
	}
	
}

- (IBAction)toggleL2TP:(id)sender {
	
	if([ l2tpType state ] == 1) {
		
		[ sharedSecret setEnabled: YES ];
		[ useKeychain setEnabled: YES ];
		
	}
	else {
		
		[ sharedSecret setEnabled: NO ];
		[ useKeychain setEnabled: NO ];
		
	}
	
}

- (IBAction)useKeychain:(id)sender {
	
	if([ useKeychain state ] == 0) {
		[ testWarn setHidden: YES ];
	}
	else {
		[ testWarn setHidden: NO ];
	}
	
}

- (IBAction)getHelp:(id)sender {
	
	[[ NSWorkspace sharedWorkspace ] openURL: [ NSURL URLWithString: @"http://www.macserve.org.uk/help/ivpn/"]];
	
}

- (IBAction)checkForUpdate:(id)sender {
	
	[ self checkUpdate:TRUE ];
	
}

- (IBAction)startupItem:(id)sender {
	
	NSFileManager *fileManager = [ NSFileManager defaultManager ];
	
	if([startupCheckbox state ] == 1) {
		
		if([ fileManager fileExistsAtPath:@"/etc/ppp/chap-secrets" ] == NO || [ fileManager fileExistsAtPath:@"/Library/Preferences/SystemConfiguration/com.apple.RemoteAccessServers.plist" ] == NO) {
				NSRunAlertPanel(@"Start server first", @"You need to have run the server at least once to use this", @"Ok", nil, nil);
			[ startupCheckbox setState:0 ];
			return;
		}
		else {
			[ self saveStartupItem ];
		}
	}
	else {
		[ self deleteStartupItem ];
	}
	
}

- (void)loadUser {
	
	NSFileManager *fileManager = [ NSFileManager defaultManager ];
	
	if([ fileManager fileExistsAtPath:@"/etc/ppp/user.plist" ] == YES) {

		NSDictionary *userDict = [ NSDictionary dictionaryWithContentsOfFile:@"/etc/ppp/user.plist" ];
		
		[ userName setStringValue:[ userDict objectForKey:@"User" ]];
		[ passWord setStringValue:[ userDict objectForKey:@"Password" ]];
		NSLog(@"User loaded");
	
	}
	
}

- (void)loadConf {
	
	NSDictionary *serverConf = nil;
	NSDictionary *L2TP = nil;
	
	NSFileManager *fileManager = [ NSFileManager defaultManager ];
	
	if([ fileManager fileExistsAtPath:@"/Library/Preferences/SystemConfiguration/com.apple.RemoteAccessServers.plist" ] == YES) {
	
		NSDictionary *conf = [ NSDictionary dictionaryWithContentsOfFile:@"/Library/Preferences/SystemConfiguration/com.apple.RemoteAccessServers.plist" ];
		
		BOOL containsPPTP = [[ conf objectForKey:@"ActiveServers" ] containsObject:@"com.apple.ppp.pptp" ];
		BOOL containsL2TP = [[ conf objectForKey:@"ActiveServers" ] containsObject:@"com.apple.ppp.l2tp" ];
		
		NSDictionary *servers = [ conf objectForKey:@"Servers" ];
		
		if(containsPPTP == YES && containsL2TP == NO) {
			serverConf = [ servers objectForKey:@"com.apple.ppp.pptp" ];
		}
		if(containsPPTP == NO) {
			[ pptpType setState: 0 ];
		}
		if(containsL2TP == YES) {
			serverConf = [ servers objectForKey:@"com.apple.ppp.l2tp" ];
			L2TP = [ serverConf objectForKey:@"L2TP" ];
			
			[ l2tpType setState: 1 ];
			[ sharedSecret setEnabled: YES ];
			[ useKeychain setEnabled: YES ];
			if([[ L2TP objectForKey:@"IPSecSharedSecret" ] isEqualToString:@"com.apple.ppp.l2tp"]) {
				[ useKeychain setState: 1 ];
			}
			else {
				[ sharedSecret setStringValue: [ L2TP objectForKey:@"IPSecSharedSecret" ]];
			}
		}
		
		NSDictionary *DNS = [ serverConf objectForKey:@"DNS" ];
		NSArray *serverAddresses = [ DNS objectForKey:@"OfferedServerAddresses" ];
		NSDictionary *IPv4 = [ serverConf objectForKey:@"IPv4" ];
		NSArray *addresses = [ IPv4 objectForKey:@"DestAddressRanges" ];
		NSArray *routeAddress = [ IPv4 objectForKey:@"OfferedRouteAddresses" ];
		NSArray *routeMask = [ IPv4 objectForKey:@"OfferedRouteMasks" ];
		
		[ startAddress setStringValue: [ addresses objectAtIndex:0 ]];
		[ endAddress setStringValue: [ addresses objectAtIndex:1 ]];
		[ primaryDNS setStringValue: [ serverAddresses objectAtIndex:0 ]];
		[ secondaryDNS setStringValue: [ serverAddresses objectAtIndex:1 ]];
		[ routerAddress setStringValue: [ routeAddress objectAtIndex:0 ]];
		[ subnetMask setStringValue: [ routeMask objectAtIndex:0 ]];
	
	NSLog(@"Config loaded");
	
	}
}

- (void)saveUser {
	
	NSDictionary *userDict = [ NSDictionary dictionaryWithObjects:[ NSArray arrayWithObjects:[ userName stringValue ],[ passWord stringValue ],nil ] forKeys: [ NSArray arrayWithObjects:@"User",@"Password",nil ]];
	
	[ userDict writeToFile:@"/tmp/user.plist" atomically: YES ];
	
	char *args[4];
	args[0] = "-f";
	args[1] = (char *)[ [ NSString stringWithString:@"/tmp/user.plist" ] UTF8String ];
	args[2] = "/etc/ppp/";
	args[3] = NULL;
	
	err = AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/bin/mv", 0, args, NULL);
	
	[[ NSString stringWithFormat:@"%@ * %@ *",[ userName stringValue ],[ passWord stringValue ]] writeToFile:@"/tmp/chap-secrets" atomically:YES];

	char *arg[4];
	arg[0] = "-f";
	arg[1] = (char *)[ [ NSString stringWithString:@"/tmp/chap-secrets" ] UTF8String ];
	arg[2] = "/etc/ppp/";
	arg[3] = NULL;
	
	err = AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/bin/mv", 0, arg, NULL);
}

- (void)saveConf {
	
	NSDictionary *L2TP = nil;
	NSDictionary *pptp = nil;
	NSDictionary *l2tp = nil;
	NSArray *ActiveServers = nil;
	NSDictionary *Servers = nil;
	NSDictionary *root = nil;

	NSArray *OfferedServerAddresses = [ NSArray arrayWithObjects: [ primaryDNS stringValue ],[ secondaryDNS stringValue ], nil ];
	NSArray *OfferedSearchDomains = [ NSArray arrayWithObjects: nil ];
	NSDictionary *DNS = [ NSDictionary dictionaryWithObjects: [ NSArray arrayWithObjects:OfferedServerAddresses,OfferedSearchDomains, nil ] forKeys:[ NSArray arrayWithObjects:@"OfferedServerAddresses",@"OfferedSearchDomains",nil ]];
	
	NSArray *DestAddressRanges = [ NSArray arrayWithObjects: [ startAddress stringValue ],[ endAddress stringValue ], nil ];
	NSArray *OfferedRouteAddresses = [ NSArray arrayWithObjects: [ routerAddress stringValue ], nil ];
	NSArray *OfferedRouteMasks = [ NSArray arrayWithObjects: [ subnetMask stringValue ], nil ];
	NSArray *OfferedRouteTypes = [ NSArray arrayWithObjects: @"Private", nil ];
	NSDictionary *IPv4 = [ NSDictionary dictionaryWithObjects: [ NSArray arrayWithObjects:@"Manual",DestAddressRanges,OfferedRouteAddresses,OfferedRouteMasks,OfferedRouteTypes,nil ] forKeys: [ NSArray arrayWithObjects: @"ConfigMethod",@"DestAddressRanges",@"OfferedRouteAddresses",@"OfferedRouteMasks",@"OfferedRouteTypes",nil ]];
		
	NSArray *AuthenticatorProtocol = [ NSArray arrayWithObjects: @"MSCHAP2", nil ];
	
	NSArray *CCPProtocols = [ NSArray arrayWithObjects: @"MPPE", nil ];
	
	NSDictionary *pptpPPP = [ NSDictionary dictionaryWithObjects: [ NSArray arrayWithObjects:AuthenticatorProtocol,[ NSNumber numberWithInt:1 ],CCPProtocols,[ NSNumber numberWithInt:1 ],[ NSNumber numberWithInt:5 ],[ NSNumber numberWithInt:60 ],@"/var/log/ppp/vpnd.log",[ NSNumber numberWithInt:1 ],[ NSNumber numberWithInt:0 ],[ NSNumber numberWithInt:1 ], nil ] forKeys: [ NSArray arrayWithObjects:@"AuthenticatorProtocol",@"CCPEnabled",@"CCPProtocols",@"LCPEchoEnabled",@"LCPEchoFailure",@"LCPEchoInterval",@"Logfile",@"MPPEKeySize128",@"MPPEKeySize40",@"VerboseLogging",nil ]];
	
	NSDictionary *l2tpPPP = [ NSDictionary dictionaryWithObjects: [ NSArray arrayWithObjects:AuthenticatorProtocol,[ NSNumber numberWithInt:1 ],[ NSNumber numberWithInt:5 ],[ NSNumber numberWithInt:60 ],@"/var/log/ppp/vpnd.log",[ NSNumber numberWithInt:1 ], nil ] forKeys: [ NSArray arrayWithObjects:@"AuthenticatorProtocol",@"LCPEchoEnabled",@"LCPEchoFailure",@"LCPEchoInterval",@"Logfile",@"VerboseLogging",nil ]];
	
	NSDictionary *Server = [ NSDictionary dictionaryWithObjects: [ NSArray arrayWithObjects:@"/var/log/ppp/vpnd.log",[ NSNumber numberWithInt:128 ],[ NSNumber numberWithInt:1 ],nil ] forKeys: [ NSArray arrayWithObjects:@"Logfile",@"MaximumSessions",@"VerboseLogging",nil ]];
	
	
	if([ pptpType state ] == 1) {

		NSDictionary *pptpInterface = [ NSDictionary dictionaryWithObjects: [ NSArray arrayWithObjects:@"PPTP",@"PPP",nil ] forKeys: [ NSArray arrayWithObjects:@"SubType",@"Type",nil ]];
		
		pptp = [ NSDictionary dictionaryWithObjects: [ NSArray arrayWithObjects:DNS,IPv4,pptpInterface,pptpPPP,Server,nil ] forKeys: [ NSArray arrayWithObjects:@"DNS",@"IPv4",@"Interface",@"PPP",@"Server",nil ]];
		
	}
	
	if([ l2tpType state ] == 1) {
		
		NSDictionary *l2tpInterface = [ NSDictionary dictionaryWithObjects: [ NSArray arrayWithObjects:@"L2TP",@"PPP",nil ] forKeys: [ NSArray arrayWithObjects:@"SubType",@"Type",nil ]];
		
		if([ useKeychain state ] == 1) {
			
			L2TP = [ NSDictionary dictionaryWithObjects: [ NSArray arrayWithObjects:@"IPSec",@"Keychain",@"com.apple.ppp.l2tp",nil ] forKeys: [ NSArray arrayWithObjects:@"Transport",@"IPSecSharedSecretEncryption",@"IPSecSharedSecret",nil ]];
		}
		else {
			
			L2TP = [ NSDictionary dictionaryWithObjects: [ NSArray arrayWithObjects:@"IPSec",[ sharedSecret stringValue ],nil ] forKeys: [ NSArray arrayWithObjects:@"Transport",@"IPSecSharedSecret",nil ]];
			
		}
		
		l2tp = [ NSDictionary dictionaryWithObjects: [ NSArray arrayWithObjects:DNS,IPv4,l2tpInterface,l2tpPPP,Server,L2TP,nil ] forKeys: [ NSArray arrayWithObjects:@"DNS",@"IPv4",@"Interface",@"PPP",@"Server",@"L2TP",nil ]];
		
	}
	
	if([ pptpType state ] == 1 && [ l2tpType state ] == 1) {
		
		Servers = [ NSDictionary dictionaryWithObjects: [ NSArray arrayWithObjects: pptp, l2tp, nil ] forKeys: [ NSArray arrayWithObjects: @"com.apple.ppp.pptp", @"com.apple.ppp.l2tp", nil ]];
		
		ActiveServers = [ NSArray arrayWithObjects:@"com.apple.ppp.pptp", @"com.apple.ppp.l2tp", nil ];
		
	}
	
	if([ pptpType state ] == 1 && [ l2tpType state ] == 0) {
		
		Servers = [ NSDictionary dictionaryWithObjects: [ NSArray arrayWithObjects: pptp, nil ] forKeys: [ NSArray arrayWithObjects: @"com.apple.ppp.pptp", nil ]];
		
		ActiveServers = [ NSArray arrayWithObjects:@"com.apple.ppp.pptp", nil ];
		
	}
	
	if([ pptpType state ] == 0 && [ l2tpType state ] == 1) {
		
		Servers = [ NSDictionary dictionaryWithObjects: [ NSArray arrayWithObjects: l2tp, nil ] forKeys: [ NSArray arrayWithObjects: @"com.apple.ppp.l2tp", nil ]];
		
		ActiveServers = [ NSArray arrayWithObjects: @"com.apple.ppp.l2tp", nil ];
		
	}
		
		root = [ NSDictionary dictionaryWithObjects: [ NSArray arrayWithObjects: ActiveServers, Servers, nil ] forKeys: [ NSArray arrayWithObjects:@"ActiveServers",@"Servers", nil ]];
	
	if ([ root writeToFile:@"/tmp/com.apple.RemoteAccessServers.plist" atomically: YES ] == YES) {
		
		char *args[4];
		args[0] = "-f";
		args[1] = (char *)[[ NSString stringWithString:@"/tmp/com.apple.RemoteAccessServers.plist" ] UTF8String ];
		args[2] = "/Library/Preferences/SystemConfiguration/";
		args[3] = NULL;
		
		err = AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/bin/mv", 0, args, NULL);
		NSLog(@"Config written successfully");
	}
	else {
		NSLog(@"Config write error");
	}
	
}

- (void)saveKeychain {
	
	const char *launchPath = [[ NSString stringWithFormat:@"%@/Contents/MacOS/saveKeychain",[[ NSBundle mainBundle ] bundlePath ]] UTF8String ];
	
	char *args[2];
	args[0] = (char *)[[ sharedSecret stringValue ] UTF8String ];
	args[1] = NULL;
	
	err = AuthorizationExecuteWithPrivileges(myAuthorizationRef, launchPath, 0, args, NULL);
	
	NSLog(@"Shared secret saved");
	
}

- (void)loadKeychain {
	
	OSStatus status;
	char *password;
	UInt32 passwordLength;
	
	status = SecKeychainSetPreferenceDomain (
											 kSecPreferencesDomainSystem
											 );
			
	status = SecKeychainFindGenericPassword (
											NULL,
											strlen("com.apple.net.racoon"),
											"com.apple.net.racoon",
											strlen("com.apple.ppp.l2tp"),
											"com.apple.ppp.l2tp",
											&passwordLength,
											(void **)&password,
											NULL
	);
	
	if(status != errSecItemNotFound) {

		[ sharedSecret setStringValue:[ NSString stringWithCString:password length:passwordLength ]];
		
		NSLog(@"Shared secret loaded");
	
	}
	
}

- (void)saveStartupItem {
	
	NSString *original = [ NSString stringWithContentsOfFile:[ NSString stringWithFormat:@"%@/startupScript",[[ NSBundle mainBundle ] resourcePath ]]];
	[ original writeToFile:@"/tmp/startupScript" atomically:YES ];

	char *args[2];
	args[0] = "/Library/StartupItems/iVPN";
	args[1] = NULL;
	
	err = AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/bin/mkdir", 0, args, NULL);
	
	char *secondArgs[4];
	secondArgs[0] = "-f";
	secondArgs[1] = (char *)[[ NSString stringWithFormat:@"/tmp/startupScript",[[ NSBundle mainBundle ] resourcePath ]] UTF8String ];
	secondArgs[2] = "/Library/StartupItems/iVPN/iVPN";
	secondArgs[3] = NULL;
	
	err = AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/bin/mv", 0, secondArgs, NULL);
	
	char *ownerArgs[3];
	ownerArgs[0] = "root:wheel";
	ownerArgs[1] = "/Library/StartupItems/iVPN/iVPN";
	ownerArgs[2] = NULL;
	
	err = AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/usr/sbin/chown", 0, ownerArgs, NULL);
	
	char *permissionArgs[3];
	permissionArgs[0] = "755";
	permissionArgs[1] = "/Library/StartupItems/iVPN/iVPN";
	permissionArgs[2] = NULL;
	
	err = AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/bin/chmod", 0, permissionArgs, NULL);
	
	char *thirdArgs[4];
	thirdArgs[0] = "-f";
	thirdArgs[1] = (char *)[[ NSString stringWithFormat:@"%@/StartupParameters.plist",[[ NSBundle mainBundle ] resourcePath ]] UTF8String ];
	thirdArgs[2] = "/Library/StartupItems/iVPN/StartupParameters.plist";
	thirdArgs[3] = NULL;
	
	err = AuthorizationExecuteWithPrivileges(myAuthorizationRef, "/bin/cp", 0, thirdArgs, NULL);
	
}

- (void)deleteStartupItem {
	
	NSAppleScript *script = [[NSAppleScript alloc] initWithSource:@"do shell script \"rm -R /Library/StartupItems/iVPN\" with administrator privileges"];
	
	NSDictionary *errorInfo;
	[script executeAndReturnError:&errorInfo];
	
}

- (void)periodicChecker:(NSTimer*)timer {
	
	if([ self checkStatus ] == 0) {		
		[ self setStatusStarted ];
		[ progIndicator stopAnimation:progIndicator ];
	}
	else {
		[ self setStatusStopped ];
		[ progIndicator stopAnimation:progIndicator ];
	}
	
}

- (int)checkStatus {
	
	processEnumerator = [[ AGProcess allProcesses ] objectEnumerator ];
	process = nil;
	
	while (process = [processEnumerator nextObject]) {
		
		if ([ processName isEqualToString: [ process command ]]) {
			
			return 0;
			
		}
	}
	return 1;
	
}

- (void)setStatusStarted {
	
	[ serverStatus setStringValue: @"Started" ];
	[ toggleServer setSelectedSegment: 0 ];
	[ startServerMenu setEnabled: NO ];
	[ stopServerMenu setEnabled: YES ];
	
}

- (void)setStatusStopped {
	
	[ serverStatus setStringValue: @"Stopped" ];
	[ toggleServer setSelectedSegment: 1 ];
	[ startServerMenu setEnabled: YES ];
	[ stopServerMenu setEnabled: NO ];
	
}

- (void)checkUpdate:(bool)yes {
	
	NSString *thisVersion = [[[ NSBundle bundleForClass: [ self class ]] infoDictionary ] objectForKey: @"CFBundleVersion" ];
	NSString *currentVersion = [ NSString stringWithContentsOfURL: [ NSURL URLWithString:@"http://www.macserve.org.uk/projects/ivpn/version.txt" ]];
	
	if([ currentVersion isEqualToString: thisVersion ]) {
		
		if( yes == TRUE ) {
			
			NSRunAlertPanel(@"There is no new Version", [ NSString stringWithFormat:@"You have the latest version of iVPN. You are using version %@", thisVersion ], @"Ok", nil, nil);
			
		}
		
	}
	else {
		
		int clickYes = NSRunAlertPanel(@"A new version is available", [ NSString stringWithFormat:@"You are using a beta version of iVPN (version %@).  The current stable version is %@. Would you like to download the stable version?", thisVersion, currentVersion ], @"Yes", @"No", nil);
        if(NSOKButton == clickYes)
        {
            [[ NSWorkspace sharedWorkspace ] openURL:[ NSURL URLWithString:@"http://www.macserve.org.uk/projects/ivpn/" ]];
			[ NSApp terminate: self ];
        }
		
	}
	
}

- (int)checkFields {
	
	if([ pptpType state ] == 0 && [ l2tpType state ] == 0) {
		NSRunAlertPanel(@"Settings Incomplete", [NSString stringWithFormat:@"You have not chosen a VPN type"], @"Ok", nil, nil);
		return 1;
	}
	
	if([[ userName stringValue ] isEqualToString:@"" ]) {
		NSRunAlertPanel(@"Settings Incomplete", [NSString stringWithFormat:@"You have not entered a user name to allow to connect"], @"Ok", nil, nil);
		return 1;
	}
	
	if([[ passWord stringValue ] isEqualToString:@"" ]) {
		NSRunAlertPanel(@"Settings Incomplete", [NSString stringWithFormat:@"You have not entered a password for the user"], @"Ok", nil, nil);
		return 1;
	}
	
	if([[ startAddress stringValue ] isEqualToString:@"" ]) {
		NSRunAlertPanel(@"Settings Incomplete", [NSString stringWithFormat:@"You have not entered a start address"], @"Ok", nil, nil);
		return 1;
	}
	
	if([[ endAddress stringValue ] isEqualToString:@"" ]) {
		NSRunAlertPanel(@"Settings Incomplete", [NSString stringWithFormat:@"You have not entered an end address"], @"Ok", nil, nil);
		return 1;
	}
	
	if([[ subnetMask stringValue ] isEqualToString:@"" ]) {
		NSRunAlertPanel(@"Settings Incomplete", [NSString stringWithFormat:@"You have not entered a subnet mask"], @"Ok", nil, nil);
		return 1;
	}

	if([[ primaryDNS stringValue ] isEqualToString:@"" ]) {
		NSRunAlertPanel(@"Settings Incomplete", [NSString stringWithFormat:@"You have not entered a DNS server"], @"Ok", nil, nil);
		return 1;
	}
	
	if([ l2tpType state ] == 1) {
		
		if([[ sharedSecret stringValue ] isEqualToString:@"" ]) {
			NSRunAlertPanel(@"Settings Incomplete", [NSString stringWithFormat:@"You have not entered a shared secret"], @"Ok", nil, nil);
			return 1;
		}
		
	}
	
	return 0;
	
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
	
	err = AuthorizationFree (myAuthorizationRef,kAuthorizationFlagDestroyRights);
	
}

@end
