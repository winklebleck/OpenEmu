//
//  OpenEmuQCNESPlugin.m
//  OpenEmuQCNES
//
//  A NES-only QC plugin for teh glitchy insanity.  Started by Dan Winckler on 11/16/08.
//

/* It's highly recommended to use CGL macros instead of changing the current context for plug-ins that perform OpenGL rendering */
//#import <OpenGL/CGLMacro.h>

#import "OpenEmuQCNESPlugin.h"

#import <Quartz/Quartz.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/gl.h>
#import <AudioToolbox/AudioToolbox.h>

#import "GameBuffer.h"
#import "GameAudio.h"
//#import "Nestopia/NESGameEmu.h"

#define	kQCPlugIn_Name				@"OpenEmu NES"
#define	kQCPlugIn_Description		@"Wraps the OpenEmu emulator - play and manipulate the NES"

static void _TextureReleaseCallback(CGLContextObj cgl_ctx, GLuint name, void* info)
{
	
	glDeleteTextures(1, &name);
}

static void _BufferReleaseCallback(const void* address, void* info)
{
	NSLog(@"called buffer release callback");
	//	free((void*)address);
}

@implementation OpenEmuQCNES

/*
Here you need to declare the input / output properties as dynamic as Quartz Composer will handle their implementation
@dynamic inputFoo, outputBar;
*/
@dynamic inputRom;
@dynamic inputControllerData;
@dynamic inputVolume;
@dynamic inputSaveStatePath;
@dynamic inputLoadStatePath;
@dynamic inputPauseEmulation;
@dynamic inputCheatCode;
@dynamic inputEnableRewinder;
@dynamic inputRewinderDirection;
@dynamic inputEnableRewinderBackwardsSound;
@dynamic inputRewinderReset;

@dynamic inputNmtRamCorrupt;
@dynamic inputNmtRamOffset;
@dynamic inputNmtRamValue;

@dynamic inputChrRamCorrupt;
@dynamic inputChrRamOffset;
@dynamic inputChrRamValue;

@dynamic outputImage;


+ (NSDictionary*) attributes
{
	/*
	Return a dictionary of attributes describing the plug-in (QCPlugInAttributeNameKey, QCPlugInAttributeDescriptionKey...).
	*/
	
	return [NSDictionary dictionaryWithObjectsAndKeys:kQCPlugIn_Name, QCPlugInAttributeNameKey, kQCPlugIn_Description, QCPlugInAttributeDescriptionKey, nil];
}

+ (NSDictionary*) attributesForPropertyPortWithKey:(NSString*)key
{
	/*
	Specify the optional attributes for property based ports (QCPortAttributeNameKey, QCPortAttributeDefaultValueKey...).
	*/
	if([key isEqualToString:@"inputRom"]) 
		return [NSDictionary dictionaryWithObjectsAndKeys:	@"ROM Path", QCPortAttributeNameKey, 
															 @"~/roms/NES/RomName.nes", QCPortAttributeDefaultValueKey, 
															nil]; 
	
	if([key isEqualToString:@"inputVolume"]) 
		return [NSDictionary dictionaryWithObjectsAndKeys:	@"Volume", QCPortAttributeNameKey, 
				[NSNumber numberWithFloat:0.5], QCPortAttributeDefaultValueKey, 
				[NSNumber numberWithFloat:1.0], QCPortAttributeMaximumValueKey,
				[NSNumber numberWithFloat:0.0], QCPortAttributeMinimumValueKey,
				nil]; 
	

	if([key isEqualToString:@"inputControllerData"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Controller Data", QCPortAttributeNameKey, nil];
	
	// NSArray with player count in index 0, index 1 is eButton "struct", which is an array which has the following indices:
	
	/*
	 enum eButton_Type {
	0 eButton_A,
	1 eButton_B,
	2 eButton_START,
	3 eButton_SELECT,
	4 eButton_UP,
	5 eButton_DOWN,
	6 eButton_RIGHT,
	7 eButton_LEFT,
	8 eButton_L,
	9 eButton_R,
	10 eButton_X,
	11 eButton_Y
	 };
	 
	*/
	
	if([key isEqualToString:@"inputSaveStatePath"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Save State", QCPortAttributeNameKey,
														@"~/roms/saves/savefilename", QCPortAttributeDefaultValueKey, 
														nil];

	if([key isEqualToString:@"inputLoadStatePath"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Load State", QCPortAttributeNameKey,
														@"~/roms/saves/loadsavefilename", QCPortAttributeDefaultValueKey, 
														nil];
	
	if([key isEqualToString:@"inputPauseEmulation"])
		return [NSDictionary dictionaryWithObjectsAndKeys:	@"Pause Emulator", QCPortAttributeNameKey,
				[NSNumber numberWithBool:NO], QCPortAttributeDefaultValueKey, 
				nil];
	
	if([key isEqualToString:@"inputCheatCode"])
		return [NSDictionary dictionaryWithObjectsAndKeys:	@"Cheat Code", QCPortAttributeNameKey,
				@"", QCPortAttributeDefaultValueKey, 
				nil];
	
	if([key isEqualToString:@"inputEnableRewinder"])
		return [NSDictionary dictionaryWithObjectsAndKeys:	@"Enable Rewinder", QCPortAttributeNameKey,
				[NSNumber numberWithUnsignedInteger:0], QCPortAttributeDefaultValueKey, 
				nil];
	
	if([key isEqualToString:@"inputRewinderDirection"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Rewinder Direction",QCPortAttributeNameKey,
				[NSArray arrayWithObjects:@"Backwards", @"Frontwards",nil], QCPortAttributeMenuItemsKey,
				[NSNumber numberWithUnsignedInteger:1], QCPortAttributeDefaultValueKey,
				[NSNumber numberWithUnsignedInteger:1], QCPortAttributeMaximumValueKey,
				nil];
	
	if([key isEqualToString:@"inputEnableRewinderBackwardsSound"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Enable Backwards Sound", QCPortAttributeNameKey,
				[NSNumber numberWithBool:NO], QCPortAttributeDefaultValueKey, 
				nil];

	if([key isEqualToString:@"inputRewinderReset"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Rewinder Reset", QCPortAttributeNameKey,
				[NSNumber numberWithBool:NO], QCPortAttributeDefaultValueKey, 
				nil];

	if([key isEqualToString:@"inputNmtRamCorrupt"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Corrupt NMT RAM", QCPortAttributeNameKey,
			    [NSNumber numberWithBool:NO], QCPortAttributeDefaultValueKey, 
				nil];
	
	if([key isEqualToString:@"inputNmtRamOffset"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"NMT RAM Offset",QCPortAttributeNameKey,
				[NSNumber numberWithUnsignedInteger:0], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithUnsignedInteger:0], QCPortAttributeDefaultValueKey,
				[NSNumber numberWithUnsignedInteger:1], QCPortAttributeMaximumValueKey,
				nil];

	if([key isEqualToString:@"inputNmtRamValue"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"NMT RAM Value",QCPortAttributeNameKey,
				[NSNumber numberWithUnsignedInteger:0], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithUnsignedInteger:0], QCPortAttributeDefaultValueKey,
				[NSNumber numberWithUnsignedInteger:1], QCPortAttributeMaximumValueKey,
				nil];
	
	if([key isEqualToString:@"inputChrRamCorrupt"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Corrupt Character RAM", QCPortAttributeNameKey,
				[NSNumber numberWithBool:NO], QCPortAttributeDefaultValueKey, 
				nil];
	
	if([key isEqualToString:@"inputChrRamOffset"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Character RAM Offset",QCPortAttributeNameKey,
				[NSNumber numberWithUnsignedInteger:0], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithUnsignedInteger:0], QCPortAttributeDefaultValueKey,
				[NSNumber numberWithUnsignedInteger:1], QCPortAttributeMaximumValueKey,
				nil];
	
	if([key isEqualToString:@"inputChrRamValue"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Character RAM Value",QCPortAttributeNameKey,
				[NSNumber numberWithUnsignedInteger:0], QCPortAttributeMinimumValueKey,
				[NSNumber numberWithUnsignedInteger:0], QCPortAttributeDefaultValueKey,
				[NSNumber numberWithUnsignedInteger:1], QCPortAttributeMaximumValueKey,
				nil];
	
	if([key isEqualToString:@"outputImage"])
		return [NSDictionary dictionaryWithObjectsAndKeys:@"Image", QCPortAttributeNameKey, nil];
	
	return nil;
}

+ (NSArray*) sortedPropertyPortKeys
{
	return [NSArray arrayWithObjects:@"inputRom", 
			@"inputControllerData", 
			@"inputVolume", 
			@"inputPauseEmulation",
			@"inputSaveStatePath", 
			@"inputLoadStatePath", 
			@"inputCheatCode", 
			@"inputEnableRewinder",
			@"inputEnableRewinderBackwardsSound",
			@"inputRewinderDirection",
			@"inputRewinderReset",
			@"inputNmtRamCorrupt",
			@"inputNmtRamOffset",
			@"inputNmtRamValue",
			@"inputChrRamCorrupt",
			@"inputChrRamOffset",
			@"inputChrRamValue",
			nil]; 
}


+ (QCPlugInExecutionMode) executionMode
{
	/*
	Return the execution mode of the plug-in: kQCPlugInExecutionModeProvider, kQCPlugInExecutionModeProcessor, or kQCPlugInExecutionModeConsumer.
	*/
	
	return kQCPlugInExecutionModeProvider;
}

+ (QCPlugInTimeMode) timeMode
{
	/*
	Return the time dependency mode of the plug-in: kQCPlugInTimeModeNone, kQCPlugInTimeModeIdle or kQCPlugInTimeModeTimeBase.
	*/
	
	return kQCPlugInTimeModeIdle;
}

- (id) init
{
	if(self = [super init])
	{
		gameLock = [[NSRecursiveLock alloc] init];
		persistantControllerData = [[NSMutableArray alloc] init];
		[persistantControllerData retain];

		NSBundle *theBundle = [NSBundle bundleForClass:[self class]];
		NSDictionary *ourBundleInfo = [theBundle infoDictionary];
		NSString *nesBundleDir = [[ourBundleInfo valueForKey:@"OENESBundlePath"] stringByStandardizingPath];
		bundle = [NSBundle bundleWithPath:nesBundleDir];
	}
	
	return self;
}

- (void) finalize
{
	/* Destroy variables intialized in init and not released by GC */
	[super finalize];
}

- (void) dealloc
{
	/* Release any resources created in -init. */
	[persistantControllerData release];
	[gameLock release];
	[super dealloc];
}

+ (NSArray*) plugInKeys
{
	/*
	 Return a list of the KVC keys corresponding to the internal settings of the plug-in.
	 */
	
	return nil;
}

- (id) serializedValueForKey:(NSString*)key;
{
	/*
	 Provide custom serialization for the plug-in internal settings that are not values complying to the <NSCoding> protocol.
	 The return object must be nil or a PList compatible i.e. NSString, NSNumber, NSDate, NSData, NSArray or NSDictionary.
	 */
	
	return [super serializedValueForKey:key];
}

- (void) setSerializedValue:(id)serializedValue forKey:(NSString*)key
{
	/*
	 Provide deserialization for the plug-in internal settings that were custom serialized in -serializedValueForKey.
	 Deserialize the value, then call [self setValue:value forKey:key] to set the corresponding internal setting of the plug-in instance to that deserialized value.
	 */
	
	[super setSerializedValue:serializedValue forKey:key];
}

@end

@implementation OpenEmuQCNES (Execution)


- (BOOL) startExecution:(id<QCPlugInContext>)context
{	
	NSLog(@"called startExecution");
//	if(loadedRom)
//	{
//		[gameAudio startAudio];
//		[gameCore start]; 
//	}
	
	return YES;
}

- (void) enableExecution:(id<QCPlugInContext>)context
{
	NSLog(@"called enableExecution");
	// if we have a ROM loaded and the patch's image output is reconnected, unpause the emulator
	if(loadedRom)
	{
		if(!self.inputPauseEmulation) 
		{
			[gameAudio startAudio];
			[gameCore pause:NO];
		}
	}
	
	/*
	Called by Quartz Composer when the plug-in instance starts being used by Quartz Composer.
	*/
}

- (BOOL) execute:(id<QCPlugInContext>)context atTime:(NSTimeInterval)time withArguments:(NSDictionary*)arguments
{
	CGLSetCurrentContext([context CGLContextObj]);
	
	// Process ROM loads
	if([self didValueForInputKeyChange: @"inputRom"] && ([self valueForInputKey:@"inputRom"] != [[OpenEmuQCNES	attributesForPropertyPortWithKey:@"inputRom"] valueForKey: QCPortAttributeDefaultValueKey]))
	{
		[self loadRom:[self valueForInputKey:@"inputRom"]];
	}
	
	if(loadedRom) {
		// Process controller data
		if([self didValueForInputKeyChange: @"inputControllerData"])
		{
			// hold on to the controller data, which we are going to feed gameCore every frame.  Mmmmm...controller data.
			if([self controllerDataValidate:[self inputControllerData]])
			{
				persistantControllerData = [NSMutableArray arrayWithArray:[self inputControllerData]]; 
				[persistantControllerData retain];
				
				[self handleControllerData];
			}
		}	
		
		// Process audio volume changes
		if([self didValueForInputKeyChange: @"inputVolume"] && ([self valueForInputKey:@"inputVolume"] != [[OpenEmuQCNES attributesForPropertyPortWithKey:@"inputVolume"] valueForKey: QCPortAttributeDefaultValueKey]))
		{
			// if inputVolume is set to 0, pause the audio
			if([self valueForInputKey: @"inputVolume"] == 0)
			{
				[gameAudio pauseAudio];
			}
			
			[gameAudio setVolume:[[self valueForInputKey:@"inputVolume"] floatValue]];
		}
		
		// Process state saving 
		if([self didValueForInputKeyChange: @"inputSaveStatePath"] && ([self valueForInputKey:@"inputSaveStatePath"] != [[OpenEmuQCNES attributesForPropertyPortWithKey:@"inputSaveStatePath"] valueForKey: QCPortAttributeDefaultValueKey]))
		{
			NSLog(@"save path changed");
			[self saveState:[[self valueForInputKey:@"inputSaveStatePath"] stringByStandardizingPath]];
		}

		// Process state loading
		if([self didValueForInputKeyChange: @"inputLoadStatePath"] && ([self valueForInputKey:@"inputLoadStatePath"] != [[OpenEmuQCNES attributesForPropertyPortWithKey:@"inputLoadStatePath"] valueForKey: QCPortAttributeDefaultValueKey]))	
		{
			NSLog(@"load path changed");
			[self loadState:[[self valueForInputKey:@"inputLoadStatePath"] stringByStandardizingPath]];
		}
		
		// Process emulation pausing 
	//	if([self didValueForInputKeyChange: @"inputPauseEmulation"])	
	//	{
	//		if([[self valueForInputKey:@"inputPauseEmulation"] boolValue])	
	//		{
	//			[gameAudio pauseAudio];
	//			[gameCore pause:YES]; 
	//			NSLog(@"pausing");
	//		}
	//		else 
	//		{
	//			[gameAudio startAudio];
	//			[gameCore pause:NO];
	//			NSLog(@"unpausing");
	//		}
	//	}
		
		// Process cheat codes
		if([self didValueForInputKeyChange: @"inputCheatCode"] && ([self valueForInputKey:@"inputCheatCode"] != [[OpenEmuQCNES attributesForPropertyPortWithKey:@"inputCheatCode"] valueForKey: QCPortAttributeDefaultValueKey]))	
		{
			NSLog(@"cheat code entered");
			[self setCode:[self valueForInputKey:@"inputCheatCode"]];
		}
		
		// process rewinder stuff
		if([self didValueForInputKeyChange: @"inputEnableRewinder"])	
		{
	//		NSLog(@"rewinder state changed");
			[self enableRewinder:[[self valueForInputKey:@"inputEnableRewinder"] boolValue]];

			if([(NESGameEmu*)gameCore isRewinderEnabled]) 
			{
				NSLog(@"rewinder is enabled");
			} else 
			{ 
				NSLog(@"rewinder is disabled");
			}
		}
		
	//	int* rewindTimer;
	//	rewindTimer = [[NSNumber alloc] initWithUnsignedInteger:0];
	//	
	//	if([nesEmu isRewinderEnabled]) 
	//	{
	//		rewindTimer++;
	//		if((rewindTimer % 60) == 0) {
	//		NSLog(@"rewind timer count is %d",rewindTimer);
	//		}
	//	} 
		
		if([self didValueForInputKeyChange: @"inputRewinderDirection"])	
		{
	//		NSLog(@"rewinder direction changed");
			[nesEmu rewinderDirection:[self valueForInputKey:@"inputRewinderDirection"]];
		}
		
		if([self didValueForInputKeyChange:@"inputEnableRewinderBackwardsSound"])
		{
			[nesEmu enableRewinderBackwardsSound:[[self valueForInputKey:@"inputEnableRewinderBackwardsSound"] boolValue]];
			
			if([nesEmu isRewinderBackwardsSoundEnabled])
			{
				NSLog(@"rewinder backwards sound is enabled");
			}
			else 
			{
				NSLog(@"rewinder backwards sound is disabled");
			}
		}

		// CORRUPTION FTW
		if(hasNmtRam && self.inputNmtRamCorrupt && ( [self didValueForInputKeyChange:@"inputNmtRamOffset"] || [self didValueForInputKeyChange:@"inputNmtRamValue"] ))
		{
			[nesEmu setNmtRamBytes:self.inputNmtRamOffset value:self.inputNmtRamValue];
		}
		
		if(hasChrRam && self.inputChrRamCorrupt && ( [self didValueForInputKeyChange:@"inputChrRamOffset"] || [self didValueForInputKeyChange:@"inputChrRamValue"] ))
		{
			[nesEmu setChrRamBytes:self.inputChrRamOffset value:self.inputChrRamValue];
		}
	}
	
	// our output image
	id	provider = nil;
	
	// handle our image output. (sanity checking)
	if(loadedRom && ([gameCore width] > 10) )
	{
		
		glEnable( GL_TEXTURE_RECTANGLE_EXT );
		
		GLenum status;
		GLuint texName;
		glGenTextures(1, &texName);
						
		glBindTexture( GL_TEXTURE_RECTANGLE_EXT, texName);
		glTexImage2D( GL_TEXTURE_RECTANGLE_EXT, 0, [gameCore internalPixelFormat], [gameCore width], [gameCore height], 0, [gameCore pixelFormat], [gameCore pixelType], [gameCore buffer]);
					
		// Check for OpenGL errors 
		status = glGetError();
		if(status)
		{
			NSLog(@"OpenGL error %04X", status);
			glDeleteTextures(1, &texName);
			texName = 0;
		}
		
		glFlushRenderAPPLE();

	#if __BIG_ENDIAN__
		provider = [context outputImageProviderFromTextureWithPixelFormat:QCPlugInPixelFormatARGB8 
															   pixelsWide:[gameCore width]
															   pixelsHigh:[gameCore height]
																	 name:texName 
																  flipped:YES 
														  releaseCallback:_TextureReleaseCallback 
														   releaseContext:NULL
															   colorSpace:CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB)
														 shouldColorMatch:YES];
	#else 
		provider = [context outputImageProviderFromTextureWithPixelFormat:QCPlugInPixelFormatBGRA8  
															   pixelsWide:[gameCore width]
															   pixelsHigh:[gameCore height]
																	 name:texName 
																  flipped:YES 
														  releaseCallback:_TextureReleaseCallback 
														   releaseContext:NULL 
															   colorSpace:CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB)
														 shouldColorMatch:YES];
	#endif

	}

	// output OpenEmu Texture - note we CAN output a nil image. This is 'correct'
	self.outputImage = provider;

	return YES;
}

- (void) disableExecution:(id<QCPlugInContext>)context
{
	NSLog(@"called disableExecution");

	// if we have a ROM running and the patch's image output is disconnected, pause the emulator
	if(loadedRom)
	{
		if(!self.inputPauseEmulation) 
		{
			[gameAudio pauseAudio];
			[gameCore pause:YES]; 
		}
//		sleep(0.5); // race condition workaround. 
	}
	/*
	Called by Quartz Composer when the plug-in instance stops being used by Quartz Composer.
	*/
}

- (void) stopExecution:(id<QCPlugInContext>)context
{
	NSLog(@"called stopExecution");
	if(loadedRom)
	{
		[gameCore stop]; 		
		[gameAudio stopAudio];
		[gameCore release];
		[gameAudio release];
		loadedRom = NO;
	}
}

# pragma mark -

-(BOOL) controllerDataValidate:(NSArray*) cData
{
	// sanity check
	if([cData count] == 2 && [[cData objectAtIndex:1] count] == 12)
	{
//		NSLog(@"validated controller data");
		return YES;
	}	
	
	return NO;
}

- (void) loadRom:(NSString*) romPath
{
	NSString* theRomPath = [romPath stringByStandardizingPath];
	BOOL isDir;

	NSLog(@"New ROM path is: %@",theRomPath);

	if([[NSFileManager defaultManager] fileExistsAtPath:theRomPath isDirectory:&isDir] && !isDir)
	{
		NSString * extension = [theRomPath pathExtension];
		NSLog(@"extension is: %@", extension);
		
		// cleanup
		if(loadedRom)
		{
			[gameCore stop];
			[gameAudio stopAudio];
			[gameCore release];
			//	[gameBuffer release];
			[gameAudio release];
			
			NSLog(@"released/cleaned up for new rom");
			
		}
		loadedRom = NO;
		hasChrRam = NO;
		hasNmtRam = NO;
		
		//load NES bundle
		gameCore = [[[bundle principalClass] alloc] init];
		
		// add a pointer to NESGameEmu so we can call NES-specific methods without getting fucking warnings
		nesEmu = (NESGameEmu*)gameCore;

		NSLog(@"Loaded NES bundle. About to load rom...");
		
		loadedRom = [gameCore load:theRomPath withParent:(NSDocument*)self ];
		
		if(loadedRom)
		{
			NSLog(@"Loaded new Rom: %@", theRomPath);
			[gameCore setup];
			
			//	gameBuffer = [[GameBuffer alloc] initWithGameCore:gameCore];
			//	[gameBuffer setFilter:eFilter_None];
			// audio!
			gameAudio = [[GameAudio alloc] initWithCore:gameCore];
			NSLog(@"initialized audio");
			
			// starts the threaded emulator timer
			[gameCore start];
			
			NSLog(@"About to start audio");
			[gameAudio startAudio];
			[gameAudio setVolume:[self inputVolume]];
			
			NSLog(@"finished loading/starting rom");			
			
			if([nesEmu getChrRamSize]) // see if the game has Character RAM 
			{
				hasChrRam = YES;
				NSLog(@"Reported Character RAM size is %i", [nesEmu getChrRamSize]);
			}
			else 
			{
				hasChrRam = NO;
				NSLog(@"This game does not have Character RAM");
			}
			
			hasNmtRam = YES;
			NSLog(@"Reported NMT RAM size is %i", [nesEmu getVRamSize]);
		}	
		else
		{
			NSLog(@"ROM did not load.");
		}
	}
	else {
		NSLog(@"bad ROM path or filename");
	}
	
}


-(void) handleControllerData
{
	// iterate through our NSArray of controller data. We know the player, we know the structure.
	// pull it out, and hand it off to our gameCore
	
	// sanity check (again? sure!)
	if([self controllerDataValidate:persistantControllerData])
	{
		
		// player number 
		NSNumber*  playerNumber = [persistantControllerData objectAtIndex:0];
		NSArray * controllerArray = [persistantControllerData objectAtIndex:1];

	//	NSLog(@"Player Number: %u", [playerNumber intValue]);

		NSUInteger i;
		for(i = 0; i < [controllerArray count]; i++)
		{
	//		NSLog(@"index is %u", i);
			if([[controllerArray objectAtIndex:i] boolValue] == TRUE) // down
			{
	//			NSLog(@"button %u is down", i);
				[gameCore buttonPressed:i forPlayer:[playerNumber intValue]];
			}		
			else if([[controllerArray objectAtIndex:i] boolValue] == FALSE) // up
			{
	//			NSLog(@"button %u is up", i);
				[gameCore buttonRelease:i forPlayer:[playerNumber intValue]];
			}
		} 
	}	
	
}

// callback for audio from plugin
- (void) refresh
{
	[gameAudio advanceBuffer];
}

- (void) saveState: (NSString *) fileName
{
	BOOL isDir;
	NSLog(@"saveState filename is %@", fileName);
	
	NSString *filePath = [fileName stringByDeletingLastPathComponent];
	
	// if the extension isn't .sav, make it so
	if([[fileName pathExtension] caseInsensitiveCompare:@"sav"] != 0) 
	{
		fileName = [fileName stringByAppendingPathExtension:@"sav"];
	}
	
	// see if directory exists
	if([[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir] && isDir)
	{
		// if so, save the state
		[gameCore saveState: fileName];
	} 
	else if (![[NSFileManager defaultManager] fileExistsAtPath:filePath])
	{
		// if not, bitch about it
		NSLog(@"Save state directory does not exist");
	}
}

- (BOOL) loadState: (NSString *) fileName
{
	BOOL isDir;	
	NSLog(@"loadState path is %@", fileName);
		
	if([[fileName pathExtension] caseInsensitiveCompare:@"sav"] != 0) 
	{
		NSLog(@"Saved state files must have the extension \".sav\" to be loaded.");
		return NO;
	}
	
	if([[NSFileManager defaultManager] fileExistsAtPath:fileName isDirectory:&isDir] && !isDir)
	{
		//DO NOT CONCERN YOURSELF WITH EFFICIENCY OR ELEGANCE AT THIS JUNCTURE, DANIEL MORGAN WINCKLER.
		
		//if no ROM has been loaded, don't load the state
		if(!loadedRom) {
			NSLog(@"no ROM loaded -- please load a ROM before loading a state");
			return NO;
			}
		else {
			[gameCore loadState: fileName];
			NSLog(@"loaded new state");
		}
	}
	else 
	{
		NSLog(@"loadState: bad path or filename");
		return NO;
	}
	return YES;
}

#pragma mark --Experimental Features--

- (void) setCode: (NSString*) cheatCode
{
	NSLog(@"cheat code is: %@",cheatCode);
	[nesEmu setCode:cheatCode];
}


- (void) enableRewinder:(BOOL) rewind
{
	[nesEmu enableRewinder:rewind];
}

@end