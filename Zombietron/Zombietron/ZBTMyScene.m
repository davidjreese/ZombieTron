//
//  ZBTMyScene.m
//  Zombietron
//
//  Created by David Reese on 1/26/14.
//  Copyright (c) 2014 David Reese. All rights reserved.
//

#import "ZBTMyScene.h"

@interface ZBTMyScene ()

// -djr: tip - i usually create 'actors' derived from SKSpriteNode so: class ZBTPlayer : SKSpriteNode
@property(nonatomic) SKSpriteNode* player;
// -djr: tip - scene graph has all actors, but its handty to have sublists around for game logic
@property(nonatomic) NSMutableSet* zombies;
// -djr: zombie swapwner, again normally I would create: class ZBTSpawner : SKNode
@property(nonatomic) SKNode* spawner;

@end

// -djr: techtalk - we need some simple vector math macros and functions
#define CGPointSubtract(p1,p2)		CGPointMake(p1.x-p2.x, p1.y-p2.y)
#define CGPointDot(p1,p2)			(p1.x * p2.x + p1.y * p2.y)
#define CGPointLengthSquared(p1)	(p1.x*p1.x + p1.y*p1.y)
#define CGPointLength(p1)			sqrt(CGPointLengthSquared(p1))
#define CGPointDistance(p1,p2)		CGPointLength(CGPointSubtract(p1,p2))

static CGPoint CGPointNormal(CGPoint p)
{
	float z = CGPointLength(p);
	if (z <= 0)
	{
		return CGPointZero;
	}
	
	return CGPointMake(p.x/z,p.y/z);
}

static float CGPointDotProduct(CGPoint v1,CGPoint v2)
{
	CGPoint m = CGPointMake(CGPointLength(v1),CGPointLength(v2));
	CGPoint v = CGPointMake(v1.x*v2.x, v1.y*v2.y);
	float V = v.x + v.y;
	float M = m.x * m.y;
    
	return M ? V/M : 0;
}

static float GetAngleForDirection(CGPoint* direction)
{
	if (CGPointEqualToPoint(*direction, CGPointZero))
	{
		return 0;
	}
	
	CGPoint n = CGPointNormal(*direction);
	
	n.y = -n.y;
	const CGPoint vRight = CGPointMake(1,0);
	
	// Calculate angle
	float dot = CGPointDotProduct(n,vRight);
	float angle = acos(dot);
	if (n.y > 0)
	{
		angle = -angle;
	}
	
	if (angle < 0)
	{
		angle += 2*M_PI;
	}
	return angle;
}

@implementation ZBTMyScene

-(SKTexture*) loadTexture:(NSString*) textureName
{
    SKTextureAtlas* atlas = [SKTextureAtlas atlasNamed:@"assets"];
    return [atlas textureNamed:textureName];
}

-(NSArray*) loadTextures:(NSArray*) textureNames
{
    NSMutableArray* array = [NSMutableArray arrayWithCapacity:[textureNames count]];
    for (NSString* textureName in textureNames)
    {
        [array addObject:[self loadTexture:textureName]];
    }
    return array;
}

-(id)initWithSize:(CGSize)size {    
    if (self = [super initWithSize:size]) {
        /* Setup your scene here */
        
        self.backgroundColor = [SKColor colorWithRed:0.15 green:0.15 blue:0.3 alpha:1.0];
        
        // -djr: techtalk - load assets (optionally async)
// -djr: show the 'atlas' in the file system and its designated by the suffix name .atlas
// -djr: techtack - drag assets.atlas into the project from the file system
        // -djr: tip - you can use images or textures, atlas is better b/c if auto combines
        // and builds sprite sheets and you have flexibility in organization of assets
        // for larger more complex games
        
        // -djr: techtalk - setup the player                
        _player = [SKSpriteNode spriteNodeWithTexture:[self loadTexture:@"player-dad-default-000019.png"]];
        [self addChild:_player];
        
        // -djr: techtalk - place the player on screen
        _player.position = CGPointMake(size.width/2,size.height/2);
        // -djr: techtalk - y is from bottom left
// -djr: techtalk - notice how the player is now up higher on the screen
//        _player.position = CGPointMake(size.width/2,size.height - size.height/4);
        
        
        // -djr: i like to keep almost all 'game logic' in actors
        // a spawner has no physical representation. just a node

        _spawner = [SKNode new];
        // -djr: if we don't add the objec to the scene it's actions wont run
        [self addChild:_spawner];
        // -djr: SKAction is how we do things. A very powerful programming langauge
        // for our objects. We can string actions together to get behaviours
        // and game logic.
        [_spawner runAction:[SKAction repeatActionForever:[SKAction sequence:@[[SKAction waitForDuration:3.f]
                                                                              , [SKAction runBlock:^{
            
            int numToSpawn = arc4random() % 5;
            for (int i = 0; i < numToSpawn; ++i)
            {
                SKSpriteNode* zombie = [SKSpriteNode spriteNodeWithTexture:[self loadTexture:@"zombie-grabber-default-0001.png"]];
                
                // -djr, lets bake zombies spawn offscreen and walk on
                zombie.position = CGPointMake(arc4random() % (int)size.width, arc4random() % (int)size.height);
                CGPoint moveTarget = CGPointZero;
                switch (arc4random()%4)
                {
                    case 0:
                        zombie.position = CGPointMake(zombie.position.x, -zombie.frame.size.height);
                        moveTarget = CGPointMake(arc4random()%(int)zombie.position.x, size.height+zombie.frame.size.height);
                        break;
                    case 1:
                        zombie.position = CGPointMake(zombie.position.x, size.height+zombie.frame.size.height);
                        moveTarget = CGPointMake(arc4random()%(int)zombie.position.x, -zombie.frame.size.height);
                        break;
                    case 2:
                        zombie.position = CGPointMake(-zombie.frame.size.width, zombie.position.y);
                        moveTarget = CGPointMake(size.width+zombie.frame.size.width,arc4random()%(int)zombie.position.y);
                        break;
                    case 3:
                        zombie.position = CGPointMake(size.width+zombie.frame.size.width,zombie.position.y);
                        moveTarget = CGPointMake(-zombie.frame.size.width,arc4random()%(int)zombie.position.y);
                        break;
                }
                // -djr: list management
                [_zombies addObject:zombie];
                [self addChild:zombie];
                
                // -djr: techtalk - more SKAction for getting them moving
#define ZombieMoveSpeed  30.f
                CGPoint offset = CGPointSubtract(moveTarget, zombie.position);
                // -djr: techtalk lets also modify the animation playback rate to account for the 'speed'
                [zombie runAction:[SKAction sequence:@[[SKAction moveTo:moveTarget duration:CGPointLength(offset) / ZombieMoveSpeed]
                                                       , [SKAction runBlock:^{
                    // -djr: list management (do this before remove from parent)
                    [_zombies removeObject:zombie];
                }]
                                                       , [SKAction removeFromParent]]]];
                // -djr: techtalk - always remove from parent last, otherwise subsequent actions don't execute

                // -djr: techtalk - lets get them pointing the proper direction. it looks weird that
                // they walk sideways
                zombie.zRotation = GetAngleForDirection(&offset);
       
//#define TT_ANIMATIONS
#ifdef TT_ANIMATIONS
                // -djr: techtalk - lets make the zombie 'animate' its walk using an SKAction
                [zombie runAction:[SKAction repeatActionForever:[SKAction animateWithTextures:[self loadTextures:@[@"zombie-grabber-walk-0001.png"
                                                                                     ,@"zombie-grabber-walk-0002.png"
                                                                                     ,@"zombie-grabber-walk-0003.png"
                                                                                     ,@"zombie-grabber-walk-0004.png"
                                                                                     ,@"zombie-grabber-walk-0005.png"
                                                                                     ,@"zombie-grabber-walk-0006.png"
                                                                                     ,@"zombie-grabber-walk-0007.png"
                                                                                     ,@"zombie-grabber-walk-0008.png"]]
                                                                      timePerFrame:1.f / 8.f
                                                                            resize:YES
                                                                           restore:NO]]];
#endif
            }
        }]]]]];        
    }
    return self;
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /* Called when a touch begins */
    
    for (UITouch *touch in touches) {
        CGPoint location = [touch locationInNode:self];

        // -djr: techtalk lets start tracking the player aim with the finger move
        CGPoint offset = CGPointSubtract(location, _player.position);
        _player.zRotation = GetAngleForDirection(&offset);
    }
}

// -djr: techtalk lets start tracking the player aim with the finger move
-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    for (UITouch *touch in touches) {
        CGPoint location = [touch locationInNode:self];
    
        CGPoint offset = CGPointSubtract(location, _player.position);
        _player.zRotation = GetAngleForDirection(&offset);
    }
}

-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */
}

@end
