//
//  SPDocument.h
//  FrameCleaner
//
//  Created by Quinn McHenry on 7/7/14.
//  Copyright (c) 2014 Small Planet. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface SPDocument : NSDocument {
    CGPoint globalMin, globalMax;
}

@property (nonatomic, retain) NSString *directoryPath;
@property (nonatomic, assign) BOOL shouldTrimImages;
@property (nonatomic, assign) BOOL removeDuplicateFrames;
@property (nonatomic, assign) BOOL compareWithMD5;


@property (nonatomic, retain) NSMutableArray *allFiles;
@property (assign) IBOutlet NSMatrix *exportMatrix;
@property IBOutlet NSImageView *imageView;

@end
