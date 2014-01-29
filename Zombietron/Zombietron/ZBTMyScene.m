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


@implementation ZBTMyScene

-(SKTexture*) loadTexture:(NSString*) textureName
{
    SKTextureAtlas* atlas = [SKTextureAtlas atlasNamed:@"assets"];
    return [atlas textureNamed:textureName];
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
       
#define TT_UNCOMMENT
#ifdef TT_UNCOMMENT
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
                [zombie runAction:[SKAction sequence:@[[SKAction moveTo:moveTarget duration:10.f]
                                                       , [SKAction runBlock:^{
                    // -djr: list management (do this before remove from parent)
                    [_zombies removeObject:zombie];
                }]
                                                       , [SKAction removeFromParent]]]];
                // -djr: techtalk - always remove from parent last, otherwise subsequent actions don't execute
            }
        }]]]]];
#endif
    }
    return self;
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /* Called when a touch begins */
    
    for (UITouch *touch in touches) {
        CGPoint location = [touch locationInNode:self];
// -djr: comment this block of code out
        SKSpriteNode *sprite = [SKSpriteNode spriteNodeWithImageNamed:@"Spaceship"];

        sprite.position = location;
        
        SKAction *action = [SKAction rotateByAngle:M_PI duration:1];
        
        [sprite runAction:[SKAction repeatActionForever:action]];
        
        [self addChild:sprite];
    }
}

-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */
}

@end
