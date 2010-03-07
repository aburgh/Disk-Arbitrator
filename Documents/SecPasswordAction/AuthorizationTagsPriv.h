/*
 * Copyright (c) 2003-2004 Apple Computer, Inc. All Rights Reserved.
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


/*
 *  AuthorizationTagsPriv.h -- private Authorization tags
 *  
 */

#ifndef _SECURITY_AUTHORIZATIONTAGSPRIV_H_
#define _SECURITY_AUTHORIZATIONTAGSPRIV_H_

/*!
	@header AuthorizationTagsPriv
	Version 1.0 10/2003

	This header contains private details for authorization services.
*/


/* meta-rightname prefixes that configure authorization for policy changes */

/*!
	@defined kConfigRightAdd
	meta-rightname for prefix adding rights.
*/
#define kAuthorizationConfigRightAdd	"config.add."
/*!
	@defined kConfigRightModify
	meta-rightname prefix for modifying rights.
*/
#define kAuthorizationConfigRightModify	"config.modify."
/*!
	@defined kConfigRightRemove
	meta-rightname prefix for removing rights.
*/
#define kAuthorizationConfigRightRemove	"config.remove."
/*!
	@defined kConfigRight
	meta-rightname prefix.
*/
#define kConfigRight					"config."

/*!
	@defined kRuleIsRoot
	canned rule for daemon to daemon convincing (see AuthorizationDB.h for public ones)
*/
#define kAuthorizationRuleIsRoot				"is-root"

/* rule classes the specify behavior */

/*!	@defined kAuthorizationRuleClass
	Specifying rule class 
*/
#define kAuthorizationRuleClass					"class"

/*! @defined kAuthorizationRuleClassUser
	Specifying user class
*/
#define kAuthorizationRuleClassUser				"user"

/*! @defined kAuthorizationRuleClassMechanisms
	Specifying evaluate-mechanisms class
*/
#define kAuthorizationRuleClassMechanisms		"evaluate-mechanisms"

/* rule attributes to specify above classes */

/*! @defined kAuthorizationRuleParameterGroup
	string, group specification for user rules. 
*/
#define kAuthorizationRuleParameterGroup		"group"

/*! @defined kAuthorizationRuleParameterKofN
	number, k specification for k-of-n
*/
#define kAuthorizationRuleParameterKofN			"k-of-n"

/*! @defined kAuthorizationRuleParameterRules
	rules specification for rule delegation (incl. k-of-n)
*/
#define kAuthorizationRuleParameterRules		"rules"

/*! @defined kAuthorizationRuleParameterMechanisms
	mechanism specification, a sequence of mechanisms to be evaluated */
#define kAuthorizationRuleParameterMechanisms	"mechanisms"

/*! @defined kAuthorizationRightParameterTimeout
	timeout if any when a remembered right expires.
	special values:
	- not specified retains previous behavior: most privileged, credential based.
	- zero grants the right once
(can be achieved with zero credential timeout, needed?)
	- all other values are interpreted as number of seconds since granted.
*/
#define kAuthorizationRightParameterTimeout	"timeout-right"

/*! @defined kAuthorizationRuleParameterCredentialTimeout
	timeout if any for the use of cached credentials when authorizing rights.
	- not specified allows for any credentials regardless of age; rights will be remembered in authorizations, removing a credential does not stop it from granting this right, specifying a zero timeout for the right will delegate it back to requiring a credential.
	- all other values are interpreted as number of seconds since the credential was created
	- zero only allows for the use of credentials created "now" // This is deprecated by means of specifying zero for kRightTimeout
*/
#define kAuthorizationRuleParameterCredentialTimeout		"timeout"

/*!	@defined kAuthorizationRuleParameterCredentialShared
	boolean that indicates whether credentials acquired during authorization are added to the shared pool.
*/
#define kAuthorizationRuleParameterCredentialShared		"shared"

/*! @defined kAuthorizationRuleParameterAllowRoot
	boolean that indicates whether to grant a right purely because the caller is root */
#define kAuthorizationRuleParameterAllowRoot		"allow-root"

/*! @defined kAuthorizationRuleParameterCredentialSessionOwner
	boolean that indicates whether to grant a right based on a valid session-owner credential */
#define kAuthorizationRuleParameterCredentialSessionOwner		"session-owner"

/*! @defined kRuleDefaultPrompt
	dictionary of localization-name and localized prompt pairs */
#define kAuthorizationRuleParameterDefaultPrompt	"default-prompt"

/*! @defined kAuthorizationRuleParameterDescription
    string, default description of right.  Usually localized versions are added using the
    AuthorizationDBSet call (@see AuthorizationDB.h). */
#define kAuthorizationRuleParameterDescription      "description"

/*! @defined kAuthorizationRuleParameterAuthenticateUser
	boolean that indicates whether to authenticate the user requesting authorization */
#define kAuthorizationRuleParameterAuthenticateUser		"authenticate-user"

/* authorization hints passed between securityd and agent */
#define AGENT_HINT_SUGGESTED_USER "suggested-user"
#define AGENT_HINT_SUGGESTED_USER_LONG "suggested-realname"
#define AGENT_HINT_REQUIRE_USER_IN_GROUP "require-user-in-group"
#define AGENT_HINT_CUSTOM_PROMPT "prompt"
#define AGENT_HINT_AUTHORIZE_RIGHT "authorize-right"
#define AGENT_HINT_CLIENT_PID "client-pid"
#define AGENT_HINT_CLIENT_UID "client-uid"
#define AGENT_HINT_CLIENT_VALIDITY "client-signature-validity"
#define AGENT_HINT_CREATOR_PID "creator-pid"
#define AGENT_HINT_CLIENT_TYPE "client-type"
#define AGENT_HINT_CLIENT_PATH "client-path"
#define AGENT_HINT_CLIENT_NAME "client-name"
#define AGENT_HINT_TRIES "tries"
#define AGENT_HINT_RETRY_REASON "reason"
#define AGENT_HINT_AUTHORIZE_RULE "authorize-rule"
#define AGENT_HINT_TOKEN_NAME "token-name"

/* passed from mechanisms to loginwindow */
#define kAuthorizationEnvironmentTokenSubserviceID "token-subservice-uid"

// remote home directory specification
#define AGENT_CONTEXT_AFP_DIR	"afp_dir"
// home directory (where it's locally mounted)
#define AGENT_CONTEXT_HOME		"home"
#define AGENT_CONTEXT_UID			"uid"
#define AGENT_CONTEXT_GID			"gid"
// kerberos principal; decoded from auth-authority specification
#define AGENT_CONTEXT_KERBEROSPRINCIPAL	"kerberos-principal"
// tell loginwindow where we're mounted
// (this should really be equal to our homedirectory according to HOME
#define AGENT_CONTEXT_MOUNTPOINT	"mountpoint"

/* authorization context passed from agent to securityd */
#define AGENT_USERNAME "username"
#define AGENT_PASSWORD "password"
#define AGENT_CONTEXT_NEW_PASSWORD "new-password"

#define AGENT_HINT_SHOW_ADD_TO_KEYCHAIN "show-add-to-keychain"
#define AGENT_ADD_TO_KEYCHAIN "add-to-keychain"

#define AGENT_CONTEXT_AUTHENTICATION_FAILURE "authentication-failure"

/* keychain panels */
// ACLowner etc. code identity panel

// Application Path is needed at this stage for identifying the application 
// for which the ACL entry is about to be updated
#define AGENT_HINT_APPLICATION_PATH "application-path"
#define AGENT_HINT_ACL_TAG "acl-tag"
#define AGENT_HINT_GROUPKEY "group-key"
#define AGENT_HINT_ACL_MISMATCH "acl-mismatch"
#define AGENT_HINT_KEYCHAIN_ITEM_NAME "keychain-item-name"
#define AGENT_HINT_KEYCHAIN_PATH "keychain-path"
#define AGENT_HINT_WINDOW_LEVEL "window-level"

#define AGENT_CONTEXT_REMEMBER_ACTION   "remember-action"
#define AGENT_CONTEXT_ALLOW   "allow"

/* Login Keychain Creation hint and context keys */

#define AGENT_HINT_ATTR_NAME "loginKCCreate:attributeName"
#define AGENT_HINT_LOGIN_KC_NAME "loginKCCreate:pathName"
#define AGENT_HINT_LOGIN_KC_EXISTS_IN_KC_FOLDER "loginKCCreate:exists"
#define AGENT_HINT_LOGIN_KC_USER_NAME "loginKCCreate:userName"
#define AGENT_HINT_LOGIN_KC_CUST_STR1 "loginKCCreate:customStr1"
#define AGENT_HINT_LOGIN_KC_CUST_STR2 "loginKCCreate:customStr2"
#define AGENT_HINT_LOGIN_KC_USER_HAS_OTHER_KCS_STR "loginKCCreate:moreThanOneKeychainExists"

/*! @defined LOGIN_KC_CREATION_RIGHT
	the right used to invoke the right mechanisms to (re)create a login
	keychain */
#define LOGIN_KC_CREATION_RIGHT	"system.keychain.create.loginkc"

/* Keychain synchronization */
// iDisk keychain blob metainfo dictionary; follows "defaults" naming
#define AGENT_HINT_KCSYNC_DICT "com.apple.keychainsync.dictionary"

#endif /* !_SECURITY_AUTHORIZATIONTAGSPRIV_H_ */
