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

@property(nonatomic) SKPhysicsBody* playerPhysicsBody;
@property(nonatomic) bool dead;
@property(nonatomic) bool readyToRespawn;
@property(nonatomic) SKLabelNode* tapToRespawnLabel;

@property(nonatomic) UITouch* shootingTouch;

@end

// -djr: techtalk - we need some simple vector math macros and functions
#define CGPointAdd(p1,p2)			CGPointMake(p1.x+p2.x, p1.y+p2.y)
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

static CGPoint GetNormalForAngle(float angle)
{
	CGAffineTransform rotation = CGAffineTransformMakeRotation(angle);
	const CGPoint vRight = CGPointMake(1,0);
	return CGPointApplyAffineTransform(vRight,rotation);
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

-(SKEmitterNode*) emitterForName:(NSString*) name
{
    return [NSKeyedUnarchiver unarchiveObjectWithFile:[[NSBundle mainBundle] pathForResource:name ofType:@"sks"]];
}

// Physics Masks
#define PhysicsMask_Board           (1<<0)
#define PhysicsMask_Prop            (1<<1)  // all props now (maybe different masks)
#define PhysicsMask_Enemy           (1<<4)
#define PhysicsMask_Player          (1<<5)
#define PhysicsMask_Bullet          (1<<8)

#define PhysicsMask_AllWorld        (PhysicsMask_Board|PhysicsMask_Prop)
#define PhysicsMask_AllNpcs         (PhysicsMask_Enemy|PhysicsMask_Player)

-(id)initWithSize:(CGSize)size {
    if (self = [super initWithSize:size]) {
        /* Setup your scene here */
        
        self.backgroundColor = [SKColor colorWithRed:0.15 green:0.15 blue:0.3 alpha:1.0];
        // -djr: tip - being able to see your physics object is imporant
        // it is possible to render the physics shapes by swizzling the physics object methods
        
// -djr: techtalk - we don't want gravity in this game
        self.physicsWorld.gravity = CGVectorMake(0, 0);
// -djr: techtalk - lets handle collision resolution now
        self.physicsWorld.contactDelegate = self;
        
        // -djr: techtalk - load assets (optionally async)
// -djr: show the 'atlas' in the file system and its designated by the suffix name .atlas
// -djr: techtack - drag assets.atlas into the project from the file system
        // -djr: tip - you can use images or textures, atlas is better b/c if auto combines
        // and builds sprite sheets and you have flexibility in organization of assets
        // for larger more complex games
        
        // -djr: techtalk - setup the player
#define PlayerRadius    48
        _player = [SKSpriteNode spriteNodeWithTexture:[self loadTexture:@"player-dad-default-000019.png"]];
        _player.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:PlayerRadius];
        _player.physicsBody.categoryBitMask = PhysicsMask_Player;
// -djr: techtalk - we do this specify what callision callbacks happen
        _player.physicsBody.contactTestBitMask = PhysicsMask_Enemy;
// -djr: techtalk - we do this to allow respawn easy
        _playerPhysicsBody = _player.physicsBody;
// -djr: techtalk - lets make sure the zombies don't push the players arounc
        _player.physicsBody.dynamic = false;
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
        
        _zombies = [NSMutableSet setWithCapacity:1024];
        [_spawner runAction:[SKAction repeatActionForever:[SKAction sequence:@[[SKAction waitForDuration:3.f]
                                                                              , [SKAction runBlock:^{
            
            int numToSpawn = arc4random() % 5;
            for (int i = 0; i < numToSpawn; ++i)
            {
                SKSpriteNode* zombie = [SKSpriteNode spriteNodeWithTexture:[self loadTexture:@"zombie-grabber-default-0001.png"]];
#define ZombieRadius    48
                zombie.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:ZombieRadius];
                zombie.physicsBody.categoryBitMask = PhysicsMask_Enemy;
// -djr: techtalk - lets let zombies overlap each other (not collide)
                zombie.physicsBody.collisionBitMask = PhysicsMask_Player;
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
                
// -djr: notice how the 'move sequence' warps the zombie around the player... that isn't cool
// -djr: if we were doing a different game, we would just set the 'velocity' of the physicsBody to allow
// physics based collisions to resolve naturally and not use an 'action' to move the zombie
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
            }
        }]]]]];
    }
    return self;
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /* Called when a touch begins */
    if (_readyToRespawn)
    {
        [_tapToRespawnLabel runAction:[SKAction sequence:@[[SKAction fadeOutWithDuration:1.f]
                                               ,[SKAction removeFromParent]]]];
        _tapToRespawnLabel = nil;
        
        for (SKNode* zombie in _zombies)
        {
            [zombie removeAllActions];
            zombie.physicsBody = nil;
            [zombie runAction:[SKAction sequence:@[[SKAction fadeOutWithDuration:1.f]
                                                   ,[SKAction removeFromParent]]]];
        }
        [_zombies removeAllObjects];
        
        [_player runAction:[SKAction setTexture:[self loadTexture:@"player-dad-default-000019.png"]]];
        _player.physicsBody = _playerPhysicsBody;
        _dead = false;
        _readyToRespawn = false;
        
        _shootingTouch = nil;
    }
    
    if (_dead)
    {
        return;
    }
    
    for (UITouch *touch in touches) {
        CGPoint location = [touch locationInNode:self];

        // -djr: techtalk lets start tracking the player aim with the finger move
        CGPoint offset = CGPointSubtract(location, _player.position);
        _player.zRotation = GetAngleForDirection(&offset);
        
        _shootingTouch = touch;

#define ShootingKey @"ShootingKey"
        [_player runAction:[SKAction repeatActionForever:[SKAction sequence:@[[SKAction runBlock:^{
            if (!_shootingTouch)
            {
                [_player removeActionForKey:ShootingKey];
            }
            
            SKSpriteNode* bullet = [SKSpriteNode spriteNodeWithTexture:[self loadTexture:@"shotgun-bullet.png"]];
#define BulletRadius    8
            bullet.physicsBody = [SKPhysicsBody bodyWithCircleOfRadius:BulletRadius];
            bullet.physicsBody.categoryBitMask = PhysicsMask_Bullet;
            // -djr: techtalk - lets let zombies overlap each other (not collide)
            bullet.physicsBody.contactTestBitMask = PhysicsMask_Enemy;
            // -djr: techtaclk - dont collide with anything
            bullet.physicsBody.collisionBitMask = 0;
            // -djr, lets bake zombies spawn offscreen and walk on
            bullet.position = _player.position;
            [self addChild:bullet];
            
            // -djr techtalk: add emitter for the muzzle flash
            SKEmitterNode *emitter = [self emitterForName:@"shotgun-muzzle-flash"];
            emitter.position = CGPointAdd(_player.position,CGPointMake(0, 0));
            emitter.zPosition = _player.zPosition + .01;
            emitter.zRotation = _player.zRotation;
            [self addChild:emitter];
            [emitter runAction:[SKAction sequence:@[
                                                    [SKAction waitForDuration:10.f]
                                                    , [SKAction removeFromParent]
                                                    , [SKAction waitForDuration:.1f]]]];

            
            CGPoint normal = GetNormalForAngle(_player.zRotation);
#define BulletVelocity  200
            bullet.physicsBody.velocity = CGVectorMake(normal.x * BulletVelocity,normal.y * BulletVelocity);
            [bullet runAction:[SKAction sequence:@[[SKAction waitForDuration:10.f]
                                                   ,[SKAction removeFromParent]]]];
        }]
                                                           ,[SKAction waitForDuration:.25f]]]] withKey:ShootingKey];
        break;
    }
}

// -djr: techtalk lets start tracking the player aim with the finger move
-(void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (_dead)
    {
        return;
    }
    
    for (UITouch *touch in touches) {
        CGPoint location = [touch locationInNode:self];
    
        CGPoint offset = CGPointSubtract(location, _player.position);
        _player.zRotation = GetAngleForDirection(&offset);
    }
}

-(void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if ([touches containsObject:_shootingTouch])
    {
        _shootingTouch = nil;
    }
}

-(void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesEnded:touches withEvent:event];
}


#pragma mark - Physics Delegate
- (void)didBeginContact:(SKPhysicsContact *)contact {
    SKNode* me = contact.bodyA.node;
    // Either bodyA or bodyB in the collision could be a character.
    SKNode* other = contact.bodyB.node;
    if (!me || !other)
    {
        return;
    }
    
    if ([_zombies containsObject:me])
    {
        SKNode* temp = me;
        me = other;
        other = temp;
    }

    if ([_zombies containsObject:other])
    {
        if (me == _player)
        {
            // kill the player
            
            _shootingTouch = nil;
            
            _tapToRespawnLabel = [SKLabelNode labelNodeWithFontNamed:@"Chalkduster"];
            
            _tapToRespawnLabel.text = @"Tap To Replay";
            _tapToRespawnLabel.fontSize = 30;
            _tapToRespawnLabel.position = CGPointMake(CGRectGetMidX(self.frame),
                                           CGRectGetMidY(self.frame));
            _tapToRespawnLabel.alpha = 0.f;
            
            [self addChild:_tapToRespawnLabel];
            
            [_tapToRespawnLabel runAction:[SKAction fadeInWithDuration:1.f]];
            
            
            _dead = true;
            _player.physicsBody = nil;
            [_player removeAllActions];
            [_player runAction:[SKAction sequence:@[[SKAction animateWithTextures:[self loadTextures:@[@"player-dad-death-000258.png"
                                                                                                               ,@"player-dad-death-000258.png"
                                                                                                               ,@"player-dad-death-000259.png"
                                                                                                               ,@"player-dad-death-000260.png"
                                                                                                               ,@"player-dad-death-000261.png"
                                                                                                               ,@"player-dad-death-000262.png"
                                                                                                               ,@"player-dad-death-000263.png"
                                                                                                               ,@"player-dad-death-000264.png"]]
                                                                             timePerFrame:1.f / 8.f
                                                                                   resize:YES
                                                                                  restore:NO]
                                                    , [SKAction waitForDuration:2.f]
                                                    , [SKAction runBlock:^{
                _readyToRespawn = true;
            }]]]];
            
            return;
        }
        
        // else its a bullet
        if (me.physicsBody.categoryBitMask & PhysicsMask_Bullet)
        {
            [me removeFromParent];
            
            // -djr techtalk: add emitter for the bile spray
            CGPoint offset = CGPointSubtract(other.position, me.position);
            SKEmitterNode *emitter = [self emitterForName:@"zombie-bile-spray"];
            emitter.position = other.position;
            emitter.zRotation = GetAngleForDirection(&offset);
            emitter.zPosition = other.zPosition + .01;
//            emitter.particleZPositionRange = Npc_RelativeOffsetZ_BloodRange;
            [self addChild:emitter];
            [emitter runAction:
             [SKAction sequence:@[
                                  [SKAction waitForDuration:5.f]
                                  , [SKAction removeFromParent]
                                  ]]];
            [self.parent addChild:emitter];
            
            [_zombies removeObject:other];
            other.physicsBody = nil;
            [other removeAllActions];
            [other runAction:[SKAction sequence:@[[SKAction animateWithTextures:[self loadTextures:@[@"zombie-grabber-death-a-0001.png"
                                                                                                       ,@"zombie-grabber-death-a-0002.png"
                                                                                                       ,@"zombie-grabber-death-a-0003.png"
                                                                                                       ,@"zombie-grabber-death-a-0004.png"
                                                                                                       ,@"zombie-grabber-death-a-0005.png"
                                                                                                       ,@"zombie-grabber-death-a-0006.png"
                                                                                                       ,@"zombie-grabber-death-a-0007.png"
                                                                                                       ,@"zombie-grabber-death-a-0008.png"]]
                                                                     timePerFrame:1.f / 8.f
                                                                           resize:YES
                                                                          restore:NO]
                                                    , [SKAction waitForDuration:2.f]
                                                    , [SKAction fadeOutWithDuration:1.f]
                                                    , [SKAction removeFromParent]]]];
        }
        
    }
}

-(void)update:(CFTimeInterval)currentTime {
    /* Called before each frame is rendered */
}

@end
