/*
 * Copyright (c) 2000-2004 Apple Computer, Inc. All Rights Reserved.
 * 
 * @APPLE_LICENSE_HEADER_START@
 * 
 * This file contains Original Code and/or Modifications of Original Code
 * as defined in and that are subject to the Apple Public Source License
 * Version 2.0 (the 'License'). You may not use this file except in
 * compliance with the License. Please obtain a copy of the License at
 * http://www.opensource.apple.com/apsl/ and read it before using this
 * file.
 * 
 * The Original Code and all software distributed under the License are
 * distributed on an 'AS IS' basis, WITHOUT WARRANTY OF ANY KIND, EITHER
 * EXPRESS OR IMPLIED, AND APPLE HEREBY DISCLAIMS ALL SUCH WARRANTIES,
 * INCLUDING WITHOUT LIMITATION, ANY WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE, QUIET ENJOYMENT OR NON-INFRINGEMENT.
 * Please see the License for the specific language governing rights and
 * limitations under the License.
 * 
 * @APPLE_LICENSE_HEADER_END@
 */

/*!
@header SecPassword
	SecPassword implements logic to use the system facilities for acquiring a password, 
    optionally stored and retrieved from the user's keychain.
 */

#include <Security/SecBase.h>
#include <Security/SecKeychainItem.h>
#include <Security/cssmapple.h>

#ifndef _SECURITY_SECPASSWORD_H_
#define _SECURITY_SECPASSWORD_H_

#if defined(__cplusplus)
extern "C" {
#endif

/*!
    @abstract Flags to specify SecPasswordAction behavior, as the application steps through the options
    Get, just get it.
    Get|Set, get it and set it if it wasn't in the keychain; client doesn't verify it before it's stored
    Get|Fail, get it and flag that the previously given or stored password is busted.
    Get|Set|Fail, same as above but also store it.
    New instead of Get toggles between asking for a new passphrase and an existing one.
*/
enum {
    kSecPasswordGet     = 1<<0, // Get password from keychain or user
    kSecPasswordSet     = 1<<1, // Set password (passed in if kSecPasswordGet not set, otherwise from user)
    kSecPasswordFail    = 1<<2,  // Wrong password (ignore item in keychain and flag error)
    kSecPasswordNew     = 1<<3  // Explicitly get a new passphrase
};

/*!
    @abstract Create an SecPassword object used to query and set a password used in the client.
            Keychain item attributes and class are optional, pass NULL if the password shouldn't be searched
            for or stored in the keychain.  Use CFRelease on 
    @param itemClass (in/opt) class of item to search for or store password as.
	@param attrList (in/opt) the list of attributes of the item to search or create.
    @param passwordRef (out) On return, a pointer to a password reference.  Release this by calling CFRelease function. 
 */
OSStatus SecGenericPasswordCreate(SecKeychainAttributeList *searchAttrList, SecKeychainAttributeList *itemAttrList, SecPasswordRef *itemRef);

/*!
    @abstract Get the password for a SecPassword, either from the user or the keychain and return it.
    Use SecKeychainItemFreeContent to free the data.
 
    @param message Message to display to the user as a CFString or nil for a default message.
        (future extension accepts CFDictionary for other hints, icon, secaccess)
    @param flags (in) The mode of operation.  See 
    @param length (out) The length of the buffer pointed to by data.
	@param data A pointer to a buffer containing the data to store.
 
 */
OSStatus SecPasswordAction(SecPasswordRef itemRef, CFTypeRef message, UInt32 flags, UInt32 *length, const void **data);
   
#if defined(__cplusplus)
}
#endif

#endif /* !_SECURITY_SECPASSWORD_H_ */
