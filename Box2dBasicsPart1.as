package
{
	/**
	 * Project files for the Box2D Basics Part 1 tutorial.
	 * URL: http://sierakowski.eu/list-of-tips/114-box2d-basics-part-1.html
	 * @author: Wojciech Sierakowski '2011 
	 */
	
	import Box2D.Collision.Shapes.b2CircleShape;
	import Box2D.Collision.Shapes.b2PolygonShape;
	import Box2D.Collision.b2WorldManifold;
	import Box2D.Common.Math.b2Vec2;
	import Box2D.Common.b2internal;
	import Box2D.Dynamics.Contacts.b2ContactEdge;
	import Box2D.Dynamics.b2Body;
	import Box2D.Dynamics.b2BodyDef;
	import Box2D.Dynamics.b2DebugDraw;
	import Box2D.Dynamics.b2Fixture;
	import Box2D.Dynamics.b2FixtureDef;
	import Box2D.Dynamics.b2World;
	
	import com.bit101.components.PushButton;
	import com.bit101.components.Text;
	
	import flash.display.Sprite;
	import flash.events.Event;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.ui.Keyboard;
	import flash.utils.getTimer;
	
	[SWF(frameRate="60", width="500", height="480")]
	public class Box2dBasicsPart1 extends Sprite
	{
		private static const GAME_AREA_WIDTH	:Number = 500;
		private static const GAME_AREA_HEIGHT	:Number = 400;
		
		private const pixelsPerMeter			:Number	= 30;
		private const timeStep					:Number	= 1.0 / 60.0;
		private const iterations				:Number	= 10;
		private const heroSpeedX				:Number	= 2;
		private const heroSpeedY				:Number	= 18;
		
		private var ourWorld:b2World;
		private var hero:b2Body;
		private var debugDraw:b2DebugDraw;
		private var canHeroJump:Boolean;
		private var heroNormal:b2Vec2;
		
		// References to PushButtons changing debug view modes
		private var debugButtons:Vector.<PushButton>;
		
		// Will keep objects containing values for debug view values 
		// and booleans indicating if particular view is enabled
		private var debugBits:Array;
		
		// Which keyboard keys are down
		private var keysDown:Array;
		
		// UI debug text fields
		private var text1:Text;
		private var text2:Text;
		private var textVelocity:Text;
		private var textPosM:Text;
		private var textPosPix:Text;
		private var startButton:PushButton;
		
		public function Box2dBasicsPart1()
		{
			if (stage) init()
			else addEventListener(Event.ADDED_TO_STAGE, init);
		}
		
		private function init():void
		{
			if (hasEventListener(Event.ADDED_TO_STAGE)) removeEventListener(Event.ADDED_TO_STAGE, init);
			
			heroNormal = new b2Vec2();
			canHeroJump = false;
			keysDown = [];
			
			initDebugUI();
			createWorld();
			initDebugDraw();
			createWorldWalls();
			createWorldObjects();
			
			//addEventListener(Event.ENTER_FRAME, updatePhysics);
			updatePhysics();
			
			stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
			stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
		}
		
		private function initDebugUI():void
		{
			var frame:Sprite = new Sprite();
			frame.graphics.lineStyle(1, 0xCCCCCC);
			frame.graphics.drawRect(1, 1, stage.stageWidth - 2, stage.stageHeight - 2);
			addChild(frame);
			
			// Debug view stuff
			debugBits = [];
			debugBits["shapeBit"] 			= {val: b2DebugDraw.e_shapeBit, 		selected: true,  order:0}; 	// Draw shapes
			debugBits["jointBit"] 			= {val: b2DebugDraw.e_jointBit, 		selected: true,  order:1}; 	// Draw joint connections
			debugBits["aabbBit"] 			= {val: b2DebugDraw.e_aabbBit, 			selected: false, order:2}; 	// Draw axis aligned bounding boxes
			debugBits["pairBit"] 			= {val: b2DebugDraw.e_pairBit, 			selected: false, order:3}; 	// Draw broad-phase pairs
			debugBits["centerOfMassBit"] 	= {val: b2DebugDraw.e_centerOfMassBit, 	selected: false, order:4}; 	// Draw center of mass frame
			debugBits["controllerBit"] 		= {val: b2DebugDraw.e_controllerBit, 	selected: false, order:5}; 	// Draw controllers
			
			debugButtons = new Vector.<PushButton>();
			
			var buttonWidth:Number = 65;
			var pb:PushButton;
			
			for (var key:String in debugBits)
			{
				pb = new PushButton(this, 5 + (buttonWidth + 1) * debugBits[key].order, 10, key, onDebugButton);
				pb.width = buttonWidth;
				pb.toggle = true;
				pb.selected = debugBits[key].selected;
				debugButtons.push(pb);
			}
			
			// Debug text fields
			textVelocity = new Text(this, 405, 10, "vel: (0.0, 0.0)");
			textVelocity.editable = false;
			textVelocity.width = 90;
			textVelocity.height = 20;
			
			textPosM = new Text(this, 405, 35, "p: (0.0, 0.0) [m]");
			textPosM.editable = false;
			textPosM.width = 90;
			textPosM.height = 20;
			
			textPosPix = new Text(this, 405, 55, "p: (0.0, 0.0) [pix]");
			textPosPix.editable = false;
			textPosPix.width = 90;
			textPosPix.height = 20;
			
			text1 = new Text(this, 5, 35, "---");
			text1.editable = false;
			text1.width = 395;
			text1.height = 20;
			
			text2 = new Text(this, 5, 55, "---");
			text2.editable = false;
			text2.width = 395;
			text2.height = 20;
			
			var startButtonWidth:Number = 300;
			var startButtonHeight:Number = 200;
			startButton = new PushButton(this, stage.stageWidth * .5 - startButtonWidth * .5, stage.stageHeight * .5 - startButtonHeight * .5, "Click to start simulation",  onStartButton);
			startButton.width = startButtonWidth;
			startButton.height = startButtonHeight;
		}
		
		private function onStartButton(e:Event):void
		{
			removeChild(startButton);
			addEventListener(Event.ENTER_FRAME, updatePhysics);
		}
		
		/**
		 * Main update function controlling hero's interaction and updating Box2D steps. 
		 */
		private function updatePhysics(e:Event = null):void
		{
			heroNormal.x = heroNormal.y = 0;
			
			updateHeroCollisions();
			
			// Control the hero's left, right and up movement.
			
			// Hero can move left if :
			// - hero doesn't press anything on his left side
			// - the LEFT key is pressed
			// - hero's speed doesn't exceed the max vertical speed value
			if (heroNormal.x >= 0 && isKeyDown(Keyboard.LEFT) && hero.GetLinearVelocity().x > -heroSpeedX)
			{
				// Apply impulse to the center point of the hero object with x direction of half max speed value   
				hero.ApplyImpulse(new b2Vec2(-heroSpeedX / 2, 0), hero.GetWorldCenter());
			}
			
			if (heroNormal.x <= 0 && isKeyDown(Keyboard.RIGHT) && hero.GetLinearVelocity().x < heroSpeedX)
			{
				hero.ApplyImpulse(new b2Vec2(heroSpeedX / 2, 0), hero.GetWorldCenter());
			}
			
			// Hero can jump if:
			// - the UP key is pressed, 
			// - update collision method set canHeroJump to true, 
			//   which is when collision normal.y is greater then zero (when the hero is standing on some object)
			// - horizontal linear velocity is less that one
			if (isKeyDown(Keyboard.UP) && canHeroJump && Math.abs(hero.GetLinearVelocity().y) <= 1)
			{
				hero.ApplyImpulse(new b2Vec2(0, -heroSpeedY / 2), hero.GetWorldCenter());
				//hero.ApplyForce(new b2Vec2(0, -heroSpeedY / 2), hero.GetWorldCenter());
				//hero.SetLinearVelocity(new b2Vec2(hero.GetLinearVelocity().x, -heroSpeedY / 2));
			}
			
			textVelocity.text = "vel: (" + hero.GetLinearVelocity().x.toFixed(1) + ", " + hero.GetLinearVelocity().y.toFixed(1) + ")";
			textPosM.text = 	"(" + hero.GetWorldCenter().x.toFixed(1)  + ", " + hero.GetWorldCenter().y.toFixed(1) + ") [m]";
			textPosPix.text = 	"(" + (hero.GetWorldCenter().x * pixelsPerMeter).toFixed(0)  + ", " + (hero.GetWorldCenter().y * pixelsPerMeter).toFixed(0) + ") [pix]";
			
			// Let Box2D do physics calculations
			ourWorld.Step(timeStep, iterations, iterations);
			ourWorld.ClearForces();
			
			// Update the debug view
			ourWorld.DrawDebugData();
		}
		
		/**
		 * Checks hero's collisions with other objects.
		 */
		private function updateHeroCollisions():void
		{
			var manifold:b2WorldManifold;
			var collisionNormal:b2Vec2 = new b2Vec2();
			
			var aabbCollisions:String = "";
			var fixtureCollisions:String = "";		
			
			canHeroJump = false;
			
			// Iterate through contact lists - all collisions that hero currently have
			for (var edge:b2ContactEdge = hero.GetContactList(); edge; edge = edge.next)
			{
				manifold = new b2WorldManifold();
				edge.contact.GetWorldManifold(manifold);
				collisionNormal = manifold.m_normal;
				
				// We still don't know whether our hero is fixtureA or fixtureB
				var fixtureA:b2Fixture = edge.contact.GetFixtureA();
				var fixtureB:b2Fixture = edge.contact.GetFixtureB();
				
				var nameA:String = fixtureA.GetUserData() ? (fixtureA.GetUserData() as UserDataInfo).name : "wall";
				var nameB:String = fixtureB.GetUserData() ? (fixtureB.GetUserData() as UserDataInfo).name : "wall";
				
				aabbCollisions += nameA == "hero" ? "" : nameA + " ";
				aabbCollisions += nameB == "hero" ? "" : nameB + " ";
				
				// If hero is in fixtureB than the normal is calculated from the colliding object's point of view
				// so to have consistent normals for hero in fixture A and B, we multiply it by minus one.
				if (nameB == "hero")
				{
					collisionNormal.x *= -1;
					collisionNormal.y *= -1;
				}
				
				// If we got here it means there is a bounding box collision (AABB).
				// To make sure that shapes are colliding we use IsTouching method.
				if (edge.contact.IsTouching())
				{
					fixtureCollisions += nameA == "hero" ? "" : nameA + " (x:" + collisionNormal.x.toFixed(2) + ", y:" + collisionNormal.y.toFixed(2) + ") ";
					fixtureCollisions += nameB == "hero" ? "" : nameB + " (x:" + collisionNormal.x.toFixed(2) + ", y:" + collisionNormal.y.toFixed(2) + ") ";
					
					// If the normal vertical value is greater than zero it means that some object is pushing the hero up.
					// In other words, the hero is standing in something.
					if (collisionNormal.y > 0)
					{
						canHeroJump = true;
					}
					
					heroNormal = collisionNormal;
				}
			}
			
			text1.text 	= aabbCollisions 		== "" ? "No AABB overlaps" 		: "AABB collisions  : " + aabbCollisions;
			text2.text 	= fixtureCollisions 	== "" ? "No fixtures overlaps" 	: "Fixture collisions: " + fixtureCollisions;
		}
		
		/**
		 * Debug push buttons event handler that sets debug view display flags.
		 */
		private function onDebugButton(e:MouseEvent):void
		{
			if (e)
			{
				var pb:PushButton = e.target as PushButton;
				debugBits[pb.label].selected = pb.selected;
			}
			
			var flags:int = 0;
			for (var key:String in debugBits)
			{
				flags |= debugBits[key].selected ? debugBits[key].val : 0;
			}
			debugDraw.SetFlags(flags);
		}
		
		/**
		 * Inits Box2D debug view and sets view flags according to defaults. 
		 */
		private function initDebugDraw():void
		{
			debugDraw = new b2DebugDraw();
			var debugSprite:Sprite = new Sprite();
			debugSprite.y = 80;
			addChild(debugSprite);
			debugDraw.SetSprite(debugSprite);
			debugDraw.SetDrawScale(pixelsPerMeter);
			debugDraw.SetFillAlpha(.3);
			debugDraw.SetLineThickness(1.0);
			//debugDraw.SetFlags(b2DebugDraw.e_shapeBit | b2DebugDraw.e_jointBit);
			onDebugButton(null);
			ourWorld.SetDebugDraw(debugDraw);
			
			addChild(startButton);
		}
		
		/**
		 * Creates the physics world.
		 */
		private function createWorld():void
		{
			// Horizontal gravity of 10
			var gravity:b2Vec2 = new b2Vec2(0.0, 10.0);
			var doSleep:Boolean = true;
			
			ourWorld = new b2World(gravity, doSleep);
			
			// Register custom contact listener for one-sided platforms
			ourWorld.SetContactListener(new CustomContactListener());
		}
		
		/**
		 * Created for static boxes around game area.
		 */		
		private function createWorldWalls():void
		{
			var wallThickness:Number = 10;
			var wallWidth:Number = 490;
			var wallHeight:Number = 390;
			
			// Definitions can be reused
			var wallShape:b2PolygonShape = new b2PolygonShape();
			var wallBodyDef:b2BodyDef = new b2BodyDef();
			var wallBody:b2Body;
			
			// Left / right wall shape
			wallShape.SetAsBox(p2m(wallThickness / 2), p2m(wallHeight / 2));
			
			// left
			wallBodyDef.position.Set(p2m(wallThickness), p2m(GAME_AREA_HEIGHT / 2));
			wallBody = ourWorld.CreateBody(wallBodyDef);
			wallBody.CreateFixture2(wallShape);
			
			// right
			wallBodyDef.position.Set(p2m(GAME_AREA_WIDTH - wallThickness), p2m(GAME_AREA_HEIGHT / 2));
			wallBody = ourWorld.CreateBody(wallBodyDef);
			wallBody.CreateFixture2(wallShape);
			
			// Top / bottom wall shape
			wallShape.SetAsBox(p2m(wallWidth / 2), p2m(wallThickness / 2));
			
			// top 
			wallBodyDef.position.Set(p2m(GAME_AREA_WIDTH / 2), p2m(wallThickness));
			wallBody = ourWorld.CreateBody(wallBodyDef);
			wallBody.CreateFixture2(wallShape);
			
			// bottom
			wallBodyDef.position.Set(p2m(GAME_AREA_WIDTH / 2), p2m(GAME_AREA_HEIGHT - wallThickness));
			wallBody = ourWorld.CreateBody(wallBodyDef);
			wallBody.CreateFixture2(wallShape);
		}
		
		/**
		 * Helper function to create objects.
		 */
		private function createWorldObjects():void
		{
			var i:int;
			
			// Create platfroms - static boxes
			createBox(10, GAME_AREA_HEIGHT / 2, GAME_AREA_WIDTH / 3, 10, false, 1, .5, false, "oneSidedPlatform0");//platform");
			createBox(120, GAME_AREA_HEIGHT - 125, GAME_AREA_WIDTH - 250, 10, false, 1, .5, false, "oneSidedPlatform1");
			
			// Create two big circles
			createCircle(10, 270, 40, false, 1, .5, false, "bigCircle1");
			createCircle(50, 260, 40, false, 1, .5, false, "bigCircle2");
			
			// Create some random dynamic boxes
			var offsetX:Number = 40;
			var offsetTopY:Number = 20;
			var offsetBottomY:Number = GAME_AREA_HEIGHT / 2;
			var maxWidthHeight:Number = 20;
			var rX:Number, rY:Number, rWidth:Number, rHeight:Number;
			var fixedRotation:Boolean;
			
			for (i = 0; i < 5; i++)
			{
				rX = Math.random() * (GAME_AREA_WIDTH - 2 * offsetX) + offsetX;
				rY = Math.random() * (GAME_AREA_HEIGHT - offsetBottomY - offsetTopY) + offsetTopY;
				rWidth = Math.random() * maxWidthHeight + 10;
				rHeight = Math.random() * maxWidthHeight + 10;
				fixedRotation = Math.random() >= .5;
				
				createBox(rX, rY, rWidth, rHeight, true, 1, .5, fixedRotation, "box" + i);
			}
			
			// Create some random triangles
			for (i = 0; i < 5; i++)
			{
				rX = Math.random() * (GAME_AREA_WIDTH - 2 * offsetX) + offsetX;
				rY = Math.random() * (GAME_AREA_HEIGHT - offsetBottomY - offsetTopY) + offsetTopY;
				rWidth = Math.random() * maxWidthHeight + 10;
				rHeight = Math.random() * maxWidthHeight + 10;
				fixedRotation = Math.random() >= .5;
				
				createTriangle(rX, rY, rWidth, rHeight, true, 1, .5, fixedRotation, "triangle" + i);
			}
			
			// Create some random circles
			var rRadius:Number;
			var maxRadius:Number = 10;
			
			for (i = 0; i < 5; i++)
			{
				rX = Math.random() * (GAME_AREA_WIDTH - 2 * offsetX) + offsetX;
				rY = Math.random() * (GAME_AREA_HEIGHT - offsetBottomY - offsetTopY) + offsetTopY;
				rRadius = Math.random() * maxRadius + 10;
				fixedRotation = false;//Math.random() >= .5;
				
				createCircle(rX, rY, rRadius, true, 1, .5, fixedRotation, "circle" + i);
			}
			
			// Create a bit more complex object - our hero
			//hero = createHero(40, 30);
			hero = createHero(60, 340);
		}
		
		/**
		 * Helper function to create objects of box shape.
		 */
		private function createBox(x:Number, y:Number, width:Number, height:Number, isDynamic:Boolean, density:Number = 1, friction:Number = .5, fixedRotation:Boolean = false, name:String = ""):b2Body
		{
			var bWidth:Number = p2m(width);
			var bHeight:Number = p2m(height);
			
			// box shape
			var shape:b2PolygonShape = new b2PolygonShape();
			shape.SetAsBox(bWidth / 2, bHeight / 2);
			
			// fixture
			var fixture:b2FixtureDef = new b2FixtureDef();
			fixture.density = density;
			fixture.friction = friction;
			fixture.shape = shape;
			fixture.userData = new UserDataInfo(name, bWidth, bHeight);
			
			// body definition
			var bodyDef:b2BodyDef = new b2BodyDef();
			bodyDef.position.Set(p2m(x) + bWidth / 2, p2m(y) + bHeight / 2);
			bodyDef.type = isDynamic ? b2Body.b2_dynamicBody : b2Body.b2_staticBody;
			bodyDef.fixedRotation = fixedRotation;
			
			// body
			var body:b2Body = ourWorld.CreateBody(bodyDef);
			body.CreateFixture(fixture);
			return body;
		}
		
		/**
		 * Helper function to create objects of triangular shape.
		 */
		private function createTriangle(x:Number, y:Number, width:Number, height:Number, isDynamic:Boolean, density:Number = 1, friction:Number = .5, fixedRotation:Boolean = false, name:String = ""):b2Body
		{
			var bWidth:Number = p2m(width);
			var bHeight:Number = p2m(height);
			
			// shape
			var shape:b2PolygonShape = new b2PolygonShape();
			var vertices:Array = [];
			vertices.push(new b2Vec2(bWidth / 2, bHeight / 2));		// right bottom
			vertices.push(new b2Vec2(-bWidth / 2, bHeight / 2)); 	// left bottom
			vertices.push(new b2Vec2(0, -bHeight / 2));				// middle top
			shape.SetAsArray(vertices);
			
			// fixture
			var fixture:b2FixtureDef = new b2FixtureDef();
			fixture.density = density;
			fixture.friction = friction;
			fixture.shape = shape;
			fixture.userData = new UserDataInfo(name, bWidth, bHeight);
			
			// body definition
			var bodyDef:b2BodyDef = new b2BodyDef();
			bodyDef.position.Set(p2m(x) + bWidth / 2, p2m(y) + bHeight / 2);
			bodyDef.type = isDynamic ? b2Body.b2_dynamicBody : b2Body.b2_staticBody;
			bodyDef.fixedRotation = fixedRotation;
			
			// body
			var body:b2Body = ourWorld.CreateBody(bodyDef);
			body.CreateFixture(fixture);
			return body;
		}
		
		/**
		 * Helper function to create objects of circular shape.
		 */
		private function createCircle(x:Number, y:Number, radius:Number, isDynamic:Boolean, density:Number = 1, friction:Number = .5, fixedRotation:Boolean = false, name:String = ""):b2Body
		{
			var bRadius:Number = p2m(radius);
			
			// circle shape
			var shape:b2CircleShape = new b2CircleShape(bRadius);
			
			// fixture
			var fixture:b2FixtureDef = new b2FixtureDef();
			fixture.density = density;
			fixture.friction = friction;
			fixture.shape = shape;
			fixture.userData = new UserDataInfo(name, bRadius * 2, bRadius * 2);
			
			// body definition
			var bodyDef:b2BodyDef = new b2BodyDef();
			bodyDef.position.Set(p2m(x) + bRadius / 2, p2m(y) + bRadius / 2);
			bodyDef.type = isDynamic ? b2Body.b2_dynamicBody : b2Body.b2_staticBody;
			bodyDef.fixedRotation = fixedRotation;
			
			// body
			var body:b2Body = ourWorld.CreateBody(bodyDef);
			body.CreateFixture(fixture);
			return body;
		}
		
		/**
		 * Helper function to create a bit more complex object made of more shapes - our hero.
		 */
		private function createHero(x:Number, y:Number):b2Body
		{
			// fixture
			var fixture:b2FixtureDef = new b2FixtureDef();
			fixture.friction = .5;
			fixture.userData = new UserDataInfo("hero", p2m(30), p2m(60)); // height: 10 * 2 + 10 * 2 + 20));
		
			// body definition
			var bodyDef:b2BodyDef = new b2BodyDef();
			bodyDef.position.Set(p2m(x + 15 / 2), p2m(y + 30 / 2));
			bodyDef.type = b2Body.b2_dynamicBody;
			bodyDef.fixedRotation = true;
			
			// body
			var body:b2Body = ourWorld.CreateBody(bodyDef);
			
			/*/
			var heroBoundingBoxShape:b2PolygonShape = new b2PolygonShape();
			heroBoundingBoxShape.SetAsBox(p2m(30 / 2), p2m(60 / 2));
			fixture.shape = heroBoundingBoxShape;
			body.CreateFixture(fixture);
			/*/
			
			// shapes
			var headShape:b2CircleShape = new b2CircleShape(p2m(10));
			headShape.b2internal::m_p.Set(0, p2m(-20));
			fixture.shape = headShape;
			body.CreateFixture(fixture);
			
			var boxShape:b2PolygonShape = new b2PolygonShape();
			boxShape.SetAsBox(p2m(15), p2m(10));
			fixture.shape = boxShape;
			body.CreateFixture(fixture);
			
			var leftLegShape:b2PolygonShape = new b2PolygonShape();
			leftLegShape.SetAsArray(
				[
					new b2Vec2(p2m(30 / 2), p2m(20 / 2)), 	// right top
					new b2Vec2(p2m(20 / 2), p2m(60 / 2)),	// right bottom
					new b2Vec2(p2m(-20 / 2), p2m(60 / 2)),	// left bottom
					new b2Vec2(p2m(-30 / 2), p2m(20 / 2))	// left top
				]);
			fixture.shape = leftLegShape;
			body.CreateFixture(fixture);
		
			return body;
		}
		
		/**
		 * Keybord event handler.
		 */
		protected function onKeyDown(e:KeyboardEvent):void
		{
			keysDown[e.keyCode] = true;
		}
		
		/**
		 * Keybord event handler.
		 */
		protected function onKeyUp(e:KeyboardEvent):void
		{
			keysDown[e.keyCode] = false;
		}

		
		// HELPER FUNCTIONS
		
		/**
		 * Converts pixels to Box2D units - meters (Pixel to Meter).
		 */
		private function p2m(pixels:Number):Number
		{
			return pixels / pixelsPerMeter;
		}
		
		/**
		 * Returns true if a key in question is currently pressed.
		 */
		public function isKeyDown(keyCode:int):Boolean
		{
			return keysDown[keyCode];
		}
	}
}

/**
 * Helper object to keep user data informations about objects: name, width and height (in meters).
 */
class UserDataInfo
{
	public var name:String;
	public var width:Number, height:Number;
	
	public function UserDataInfo(name:String = "", width:Number = 0, height:Number = 0):void
	{
		this.name = name;
		this.width = width;
		this.height = height;
	}
}


import Box2D.Collision.b2Manifold;
import Box2D.Common.Math.b2Vec2;
import Box2D.Dynamics.Contacts.b2Contact;
import Box2D.Dynamics.b2Body;
import Box2D.Dynamics.b2ContactListener;
import Box2D.Dynamics.b2Fixture;

/**
 * Custom Contact Listener for one sided platforms.
 */
class CustomContactListener extends b2ContactListener
{
	override public function PreSolve(contact:b2Contact, oldManifold:b2Manifold):void 
	{
		var fixtureA:b2Fixture = contact.GetFixtureA();
		var fixtureB:b2Fixture = contact.GetFixtureB();
		
		// If any of the two fixtures doesn't have the user data object then return,
		// as we need 'hero' and 'oneSidedPlatform' objects only.
		if (!fixtureA.GetUserData() || !fixtureB.GetUserData()) return;
		
		var nameA:String = (fixtureA.GetUserData() as UserDataInfo).name;
		var nameB:String = (fixtureB.GetUserData() as UserDataInfo).name;
		
		if (nameA != "hero" && nameB != "hero") return;
		if (nameA.indexOf("oneSidedPlatform") == -1 && nameB.indexOf("oneSidedPlatform") == -1) return;
		
		// Now find out which is hero and which is platform and get their position and height.
		var heroPos:b2Vec2, platformPos:b2Vec2;
		var heroHeight:Number, platformHeight:Number;
		
		if (nameA == "hero")
		{
			heroPos = fixtureA.GetBody().GetPosition();
			heroHeight = (fixtureA.GetUserData() as UserDataInfo).height;
			
			platformPos = fixtureB.GetBody().GetPosition();
			platformHeight = (fixtureB.GetUserData() as UserDataInfo).height;
		}
		else
		{
			platformPos = fixtureA.GetBody().GetWorldCenter();
			platformHeight = (fixtureA.GetUserData() as UserDataInfo).height;
			
			heroPos = fixtureB.GetBody().GetWorldCenter();
			heroHeight = (fixtureB.GetUserData() as UserDataInfo).height;
		}
		
		// If the bottom part of the hero is under a top part of a platform then do not create collision.
		// As the hero position is in the middle of the hero object we need to add half of his height
		// to get the position at the bottom of his legs. Similar for platform but we need to substract
		// half of it's height to get the position of the top of it.
		if (heroPos.y + heroHeight / 2 > platformPos.y - platformHeight / 2)
		{
			contact.SetEnabled(false);
		}
	}
}