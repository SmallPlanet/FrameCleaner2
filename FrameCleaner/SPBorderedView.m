//
//  SPBorderedView.m
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/9/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import "SPBorderedView.h"

@implementation SPBorderedView

- (id) initWithFrame:(NSRect)frameRect {
    self = [super initWithFrame:frameRect];
    if (self) {
        CALayer *layer = [CALayer layer];
        layer.frame = self.bounds;
        layer.borderColor = [NSColor redColor].CGColor;
        layer.borderWidth = 1.f;
        self.layer = layer;
        [self setWantsLayer:YES];
    }
    return self;
}

@end
