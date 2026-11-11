/*****************************************************************************\
     Snes9x - Portable Super Nintendo Entertainment System (TM) emulator.
                This file is licensed under the Snes9x License.
   For further information, consult the LICENSE file in the root directory.
\*****************************************************************************/

/***********************************************************************************
  SNES9X for Mac OS (c) Copyright John Stiles

  Snes9x for Mac OS X

  (c) Copyright 2001 - 2011  zones
  (c) Copyright 2002 - 2005  107
  (c) Copyright 2002         PB1400c
  (c) Copyright 2004         Alexander and Sander
  (c) Copyright 2004 - 2005  Steven Seeger
  (c) Copyright 2005         Ryan Vogt
  (c) Copyright 2019 - 2022  Michael Donald Buckley
 ***********************************************************************************/


#include "port.h"
#include "cheats.h"

#define __STDC_FORMAT_MACROS
#include <inttypes.h>

#include "mac-prefix.h"
#include "mac-dialog.h"
#include "mac-os.h"
#include "mac-stringtools.h"
#include "mac-cheat.h"

#define	kDataBrowser	'BRSR'
#define	kCmCheckBox		'CHK_'
#define	kCmAddress		'ADDR'
#define	kCmValue		'VALU'
#define	kCmDescription	'DESC'
#define	kNewButton		'NEW_'
#define	kDelButton		'DEL_'
#define	kAllButton		'ALL_'

extern SCheatData	Cheat;

bool S9xGameGenieToRaw(const std::string &code, uint32 &address, uint8 &byte);
bool S9xProActionReplayToRaw(const std::string &code, uint32 &address, uint8 &byte);

static bool ValidateCheatID(uint32 cheatID)
{
    if (cheatID < Cheat.group.size())
        return true;

    [NSApp presentError:[NSError errorWithDomain:@"com.snes9x" code:2 userInfo:@{
        NSLocalizedDescriptionKey: NSLocalizedString(@"This cheat is no longer available. Refresh the cheat list and try again.", nil)
    }]];
    return false;
}

@interface S9xCheatItem ()
@property (nonatomic, weak) S9xEngine *engine;
- (instancetype)initWithCheatID:(uint32)cheatID engine:(S9xEngine *)engine;
@end

@implementation S9xCheatItem

@synthesize address = _address;
@synthesize value = _value;
@synthesize enabled = _enabled;
@synthesize cheatDescription = _cheatDescription;

- (instancetype)initWithCheatID:(uint32)cheatID engine:(S9xEngine *)engine
{
    if ((self = [super init]))
    {
        _cheatID = cheatID;
        _engine = engine;
        _romGeneration = engine.romGeneration;
        const auto &group = Cheat.group[cheatID];
        _address = @(group.cheat[0].address);
        _value = @(group.cheat[0].byte);
        _enabled = @(group.enabled);
        _cheatDescription = [NSString stringWithUTF8String:group.name.c_str()];
    }
    return self;
}

- (void)applySnapshot
{
    uint32 cheatID = self.cheatID;
    uint32 address = self.address.unsignedIntValue;
    uint8 value = self.value.unsignedCharValue;
    BOOL enabled = self.enabled.boolValue;
    NSString *description = self.cheatDescription;
    [self.engine performForROMGeneration:self.romGeneration action:^
    {
        if (!ValidateCheatID(cheatID))
            return;
        char code[32];
        snprintf(code, sizeof(code), "%x=%x", address, value);
        S9xModifyCheatGroup(cheatID, description.UTF8String, code);

        if (enabled)
            S9xEnableCheatGroup(cheatID);
    }];
}

- (void)setAddress:(NSNumber *)address
{
    _address = address;
    [self applySnapshot];
}

- (void)setValue:(NSNumber *)value
{
    _value = value;
    [self applySnapshot];
}

- (void)setEnabled:(NSNumber *)enabled
{
    _enabled = enabled;
    uint32 cheatID = self.cheatID;
    [self.engine performForROMGeneration:self.romGeneration action:^
    {
        if (!ValidateCheatID(cheatID))
            return;
        if (enabled.boolValue)
            S9xEnableCheatGroup(cheatID);
        else
            S9xDisableCheatGroup(cheatID);
    }];
}

- (void)setCheatDescription:(NSString *)cheatDescription
{
    _cheatDescription = [cheatDescription copy];
    [self applySnapshot];
}

- (void)delete
{
    uint32 cheatID = self.cheatID;
    [self.engine performForROMGeneration:self.romGeneration action:^
    {
        if (!ValidateCheatID(cheatID))
            return;
        S9xDeleteCheatGroup(cheatID);
    }];
}

@end

extern "C"
{

bool CheatValuesFromCode(NSString *code, uint32 *address, uint8 *value)
{
	const char *text = code.UTF8String;

	if (!S9xGameGenieToRaw (text, *address, *value))
	{
		return true;
	}

	if (!S9xProActionReplayToRaw (text, *address, *value))
	{
		return true;
	}

	else if (sscanf (text, "%x = %x", (unsigned int *)address, (unsigned int *)value) == 2)
	{
		return true;
	}

	else if (sscanf (text, "%x / %x", (unsigned int *)address, (unsigned int *)value) == 2)
	{
		return true;
	}

	return false;
}

void CreateCheatFromAddress(NSNumber *address, NSNumber *value, NSString *cheatDescription)
{
	char code[256];
	sprintf(code, "%x=%x", address.unsignedIntValue, value.unsignedCharValue);
	S9xAddCheatGroup(cheatDescription.UTF8String, code);
	S9xEnableCheatGroup(Cheat.group.size() - 1);
}

void CreateCheatFromCode(NSString *code, NSString *cheatDescription)
{
	S9xAddCheatGroup(cheatDescription.UTF8String, code.UTF8String);
	S9xEnableCheatGroup(Cheat.group.size() - 1);
}

NSArray<S9xCheatItem *> *GetAllCheats(S9xEngine *engine)
{
	NSMutableArray *cheats = [NSMutableArray new];
	uint32 cheatID = 0;

	for (const auto &group : Cheat.group)
	{
        if (!group.cheat.empty())
            [cheats addObject:[[S9xCheatItem alloc] initWithCheatID:cheatID engine:engine]];
        ++cheatID;
	}

	return cheats;
}
}
