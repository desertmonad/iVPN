
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
#include <Security/Security.h>
#include <CoreFoundation/CoreFoundation.h>
#include <string.h>


SecAccessRef createAccess(NSString *accessLabel) {
	
    OSStatus err;
    SecAccessRef access = nil;
    NSArray *trustedApplications = nil;

    SecTrustedApplicationRef saveKeychain, ivpn, racoon;

    err = SecTrustedApplicationCreateFromPath(NULL, &saveKeychain);
    err = SecTrustedApplicationCreateFromPath("/Applications/iVPN.app", &ivpn);
	err = SecTrustedApplicationCreateFromPath("/usr/sbin/racoon", &racoon);
    trustedApplications = [ NSArray arrayWithObjects:(id)saveKeychain, (id)ivpn, (id)racoon, nil ];

    err = SecAccessCreate((CFStringRef)accessLabel, (CFArrayRef)trustedApplications, &access);
    if (err) return nil;
	
    return access;
	
}


void addGenericPassword(const char *password, NSString *account, NSString *service, NSString *itemLabel) {
	
    OSStatus err;
    SecKeychainItemRef item = nil;
    const char *serviceUTF8 = [ service UTF8String ];
    const char *accountUTF8 = [ account UTF8String ];
    const char *itemLabelUTF8 = [ itemLabel UTF8String ];
	
    SecAccessRef access = createAccess(itemLabel);

    SecKeychainAttribute attrs[] = {
        { kSecLabelItemAttr, strlen(itemLabelUTF8), (char *)itemLabelUTF8 },
        { kSecAccountItemAttr, strlen(accountUTF8), (char *)accountUTF8 },
        { kSecServiceItemAttr, strlen(serviceUTF8), (char *)serviceUTF8 }
    };
    SecKeychainAttributeList attributes = { sizeof(attrs) / sizeof(attrs[0]),
	attrs };
	
    err = SecKeychainItemCreateFromContent(
										   kSecGenericPasswordItemClass,
										   &attributes,
										   strlen(password),
										   password,
										   NULL,
										   access,
										   &item);
	
    if (access) CFRelease(access);
    if (item) CFRelease(item);
	
}


int main(int argc, const char *argv[]) {
	
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	OSStatus err;
	const char *password = argv[1];
	SecKeychainItemRef itemRef = nil;
	
	err = SecKeychainSetPreferenceDomain (kSecPreferencesDomainSystem);
	
	err = SecKeychainFindGenericPassword (
											 NULL,
											 strlen("com.apple.net.racoon"),
											 "com.apple.net.racoon",
											 strlen("com.apple.ppp.l2tp"),
											 "com.apple.ppp.l2tp",
											 NULL,
											 NULL,
											 &itemRef
											 );
	
	if(err == errSecItemNotFound) {

    addGenericPassword(password, @"com.apple.ppp.l2tp", @"com.apple.net.racoon", @"com.apple.net.racoon");
	
	}
	else {
		
		err = SecKeychainItemModifyAttributesAndData (
														 itemRef,
														 NULL,
														 strlen(password),
														 (void *)password
														 );
		
	}
	
    [pool release];
	
    return 0;
	
}