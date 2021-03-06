/*
 Copyright (c) 2012, OpenEmu Team
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 * Redistributions of source code must retain the above copyright
 notice, this list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright
 notice, this list of conditions and the following disclaimer in the
 documentation and/or other materials provided with the distribution.
 * Neither the name of the OpenEmu Team nor the
 names of its contributors may be used to endorse or promote products
 derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY OpenEmu Team ''AS IS'' AND ANY
 EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL OpenEmu Team BE LIABLE FOR ANY
 DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */


#import "OEDistantView.h"
#import "NSView+FadeImage.h"
#import "OEDistantViewController.h"

@interface OEDistantView ()
@property (strong) NSBitmapImageRep *distantViewImage;
@end

@implementation OEDistantView
@synthesize distantViewImage, controller;

- (void)willMakeFadeImage
{
    NSBitmapImageRep *rep = [[[[self controller] distantWindow] contentView] fadeImage];
    [self setDistantViewImage:rep];
    [self display];
}

- (void)drawRect:(NSRect)dirtyRect
{
   if([self distantViewImage])
       [[self distantViewImage] drawInRect:[self bounds]];
    else
        [super drawRect:dirtyRect];
}

- (void)didMakeFadeImage
{
    [self setDistantViewImage:nil];
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    if([self window])
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowWillMiniaturizeNotification object:[self window]];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidMiniaturizeNotification object:[self window]];
    }

    if(newWindow)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowWillMiniaturize:) name:NSWindowWillMiniaturizeNotification object:newWindow];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidMiniaturize:) name:NSWindowDidMiniaturizeNotification object:[self window]];
    }
}

- (void)windowWillMiniaturize:(NSNotification*)notification
{
    [self willMakeFadeImage];
}

- (void)windowDidMiniaturize:(NSNotification*)notification
{
    [self didMakeFadeImage];
}
@end
