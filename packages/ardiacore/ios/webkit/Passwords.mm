#import "../ArdiaServices.h"
#import "../ArdiaHost.h"
#import "../ArdiaLaunchConfig.h"
#import "../ArdiaRuntime.h"
#import <AppKit/AppKit.h>

extern "C" void ArdiaWebKitPasswordsCall(NSString *, NSString *, NSDictionary *, void (^)(NSDictionary *));

void WebKitWipePasswordBuffer(NSMutableData *data) { ardia_runtime::WipeSecret(data); }

static void PasswordCall(NSString *name, NSString *profile, NSDictionary *args, ArdiaServiceReply reply) {
  ArdiaWebKitPasswordsCall(name, profile, args ?: @{}, ^(NSDictionary *result) {
    if (result[@"error"]) reply(nil, result[@"error"]);
    else reply(result, nil);
  });
}

@implementation ArdiaServices (WebKitPasswords)
+ (void)listPasswords:(NSString *)profile reply:(ArdiaServiceReply)reply {
  PasswordCall(@"ac_passwords_list", profile, nil, reply);
}
+ (void)unlockPasswords:(NSString *)profile reply:(ArdiaServiceReply)reply {
  PasswordCall(@"ac_passwords_unlock", profile, nil, reply);
}
+ (void)password:(NSString *)profile origin:(NSString *)origin username:(NSString *)username reply:(ArdiaServiceReply)reply {
  PasswordCall(@"ac_passwords_reveal", profile, @{@"origin": origin, @"username": username}, reply);
}
+ (void)savePassword:(NSString *)profile origin:(NSString *)origin username:(NSString *)username password:(NSString *)password reply:(ArdiaServiceReply)reply {
  PasswordCall(@"ac_passwords_add", profile, @{@"origin": origin, @"username": username, @"password": password}, reply);
}
+ (void)updatePassword:(NSString *)profile origin:(NSString *)origin username:(NSString *)username newUsername:(NSString *)newUsername newPassword:(NSString *)newPassword reply:(ArdiaServiceReply)reply {
  NSMutableDictionary *args = [@{@"origin": origin, @"username": username} mutableCopy];
  if (newUsername) args[@"newUsername"] = newUsername;
  if (newPassword) args[@"newPassword"] = newPassword;
  PasswordCall(@"ac_passwords_update", profile, args, reply);
}
+ (void)deletePassword:(NSString *)profile origin:(NSString *)origin username:(NSString *)username reply:(ArdiaServiceReply)reply {
  PasswordCall(@"ac_passwords_remove", profile, @{@"origin": origin, @"username": username}, reply);
}
+ (void)neverSaveOrigins:(NSString *)profile reply:(ArdiaServiceReply)reply {
  PasswordCall(@"ac_passwords_exceptions", profile, nil, reply);
}
+ (void)allowSaving:(NSString *)profile origin:(NSString *)origin reply:(ArdiaServiceReply)reply {
  PasswordCall(@"ac_passwords_allow", profile, @{@"origin": origin}, reply);
}
+ (void)exportPasswords:(NSString *)profile path:(NSString *)path reply:(ArdiaServiceReply)reply {
  if (path.length) return PasswordCall(@"ac_passwords_export", profile, @{@"path": path}, reply);
  if (ArdiaLaunchConfig.shared.background || ArdiaLaunchConfig.shared.isolated) return reply(@{@"status": @"cancelled"}, nil);
  NSSavePanel *panel = NSSavePanel.savePanel;
  panel.nameFieldStringValue = @"Ardia Passwords.csv";
  panel.message = @"Anyone who can open this file can read your passwords.";
  [panel beginWithCompletionHandler:^(NSModalResponse response) {
    if (response != NSModalResponseOK) return reply(@{@"status": @"cancelled"}, nil);
    PasswordCall(@"ac_passwords_export", profile, @{@"path": panel.URL.path}, reply);
  }];
}
+ (BOOL)profileToggle:(ArdiaProfileToggle)toggle profile:(NSString *)profile {
  if (toggle != ArdiaProfileTogglePasswordsOffered) return NO;
  return ![WebKitProfileSettings([ArdiaHost baseProfileOf:profile], @"passwords")[@"offered"] isEqual:@NO];
}
+ (void)setProfileToggle:(ArdiaProfileToggle)toggle value:(BOOL)value profile:(NSString *)profile {
  if (toggle != ArdiaProfileTogglePasswordsOffered || [ArdiaHost isPrivateProfile:profile]) return;
  WebKitSetProfileSetting(profile, @"passwords", @"offered", @(value));
}
@end
