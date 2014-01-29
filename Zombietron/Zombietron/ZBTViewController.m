//
//  ZBTViewController.m
//  Zombietron
//
//  Created by David Reese on 1/26/14.
//  Copyright (c) 2014 David Reese. All rights reserved.
//

#import "ZBTViewController.h"
#import "ZBTMyScene.h"

@implementation ZBTViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Configure the view.
    SKView * skView = (SKView *)self.view;
    skView.showsFPS = YES;
    skView.showsNodeCount = YES;
    
    // Create and configure the scene.
    SKScene * scene = [ZBTMyScene sceneWithSize:skView.bounds.size];
    scene.scaleMode = SKSceneScaleModeAspectFill;
    
    // -djr: tip - use the scale mode with SKAction to use 1 set of assets for
    // all devices. Master your assets at iPad Retina display. Just scale the scene
    // to fit the display of smaller devices.
    
    // -djr: tip - load the assets in a Async action to allow the UI thread to keep
    // updating. This allows for a loading animation. I typically pass in the callback
    // handler here and advance the UI once it completes from this
    // part of the code
    
    // Present the scene.
    [skView presentScene:scene];
}

- (BOOL)shouldAutorotate
{
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskAllButUpsideDown;
    } else {
        return UIInterfaceOrientationMaskAll;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

@end
