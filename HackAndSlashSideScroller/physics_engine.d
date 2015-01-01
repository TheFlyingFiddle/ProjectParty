module physics_engine;

import math.vector;

struct Circle
{
	float radius;
	float2 position;
}

bool colides(Bounds a, Bounds b)
{
	if(a.max.x < b.min.x || a.min.x > b.max.x) return false;
	if(a.max.y < b.min.y || a.min.y > b.max.y) return false;

	return true;
}

bool colides(Circle a, Circle b)
{
	float r = (a.radius + b.radius) ^^ 2;
	return r < distanceSquared(a.position, b.position);
}


//bool colidesCircle(Mainfold* m)
//{
//    auto a = m.a;
//    auto b = m.b;
//
//
//    float2 n = b.pos - a.pos;
//    float  r = (a.radius + b.radius) ^^ 2;
//    if(dot(n,n) > r) return false;
//
//    float d = n.magnitude;
//    if(d != 0)
//    {
//        m.penetration = r - d;
//        m.normal	  = n / d;
//        return true;
//    }
//    else 
//    {
//        m.penetration = a.radius;
//        m.normal	  = float2(1,0);
//        return true;
//    }
//}


import framework.entity;
import components;
import math.matrix;
import std.math;
import std.algorithm : max, min;

struct Mainfold
{
	Entity* a;
	Entity* b;

	float penetration;
	float2 normal;

	float2[2] contacts;
	uint	  contactCount;

	float bounciness, dynFriction, statFriction;
}

void initMainfold(Mainfold* m, float dt)
{
	auto a = m.a.getComp!(Physics);
	auto b = m.b.getComp!(Physics);

	auto at = m.a.getComp!(Transform);
	auto bt = m.b.getComp!(Transform);

	m.bounciness   = min(a.bounciness, b.bounciness);	
	m.statFriction = sqrt( a.staticFriction ^^ 2 +  b.staticFriction ^^ 2);
	m.dynFriction  = sqrt(a.dynamicFriction ^^ 2 + b.dynamicFriction ^^ 2);

	foreach(i; 0 .. m.contactCount)
	{
		auto ra = m.contacts[i] - at.position;
		auto rb = m.contacts[i] - bt.position;

		auto rv = b.velocity + cross2D(b.angularVelocity, rb) - 
			      a.velocity - cross2D(a.angularVelocity, ra);

		//FIX IS BAD
		float2 gravity = float2(0, -2000) * dt;
		if(dot(rv, rv) < dot(gravity, gravity) + 0.0001f)
			m.bounciness = 0.0f;
	}
}

void handleCollision(Entity* a, Entity* b, float dt)
{
	Mainfold fold = Mainfold(a, b);
	if(colidesPolyPoly(&fold))
	{
		import std.stdio;
		initMainfold(&fold, dt);
		resolveCollision(&fold);
		positionalCorrection(&fold, dt);
	}	
}

bool colidesPolyPoly(Mainfold* m)
{
	auto at = m.a.getComp!(Transform);
	auto bt = m.b.getComp!(Transform);

	auto ab = m.a.getComp!Bounds;
	auto bb = m.b.getComp!Bounds;


	float2[4] polyA, polyB;
	ab.transformedCorners(*at, polyA[]);
	bb.transformedCorners(*bt, polyB[]);

	import collision;
	return colides(m, polyA[], polyB[]);
}


void applyImpulse(Physics* p, float2 impulse, float2 contact)
{
	import std.stdio;
	writeln("Impulse: ", impulse);

	p.velocity += impulse * p.invMass;
	p.angularVelocity += p.invInertia * cross2D(contact, impulse * p.invMass);
}

void resolveCollision(Mainfold* m)
{
	auto ap = m.a.getComp!(Physics);
	auto bp = m.b.getComp!(Physics);

	auto at = m.a.getComp!(Transform);
	auto bt = m.b.getComp!(Transform);

	foreach(i; 0 .. m.contactCount)
	{
		auto ra = m.contacts[i] - at.position;
		auto rb = m.contacts[i] - bt.position;

		auto rv = bp.velocity + cross2D(bp.angularVelocity, rb) - 
				  ap.velocity - cross2D(ap.angularVelocity, ra);

		float contactVel = dot(rv, m.normal);

		float raCrossN = cross2D(ra, m.normal);
		float rbCrossN = cross2D(rb, m.normal);
		float invMassSum = (ap.invMass + 
			                ap.invMass  + 
						    (raCrossN ^^ 2) * ap.invInertia +
						    (rbCrossN ^^ 2) * bp.invInertia) * m.contactCount;

		float j = -(1.0 + m.bounciness) * contactVel / (invMassSum);

		float2 impulse = m.normal * j;
		applyImpulse(ap, -impulse, ra);
		applyImpulse(bp, impulse, rb);

		float2 tangent = rv - (m.normal * dot(m.normal, rv));
		if(tangent == float2.zero) continue;

		tangent.normalize;

		float jt = -dot(rv, tangent) / (invMassSum);

		float2 frictionImpulse;
		if(abs(jt) < j * m.statFriction)
			frictionImpulse = tangent * jt;
		else 
			frictionImpulse = tangent * -j * m.dynFriction;

		applyImpulse(ap, -frictionImpulse, ra);
		applyImpulse(bp, frictionImpulse, rb);
	}
}


float cross2D(float2 a, float2 b)
{
	return a.x * b.y - a.y * b.x;
}

float2 cross2D(float2 a, float s)
{
    return float2(s * a.y, -s * a.x);
}

float2 cross2D(float s, float2 a)
{
	return float2(-s * a.y, s * a.x );
}


void positionalCorrection(Mainfold* m, float delta)
{
	auto at = m.a.getComp!(Transform);
	auto bt = m.b.getComp!(Transform);

	auto ap = m.a.getComp!(Physics);
	auto bp = m.b.getComp!(Physics);

	float invAmass = ap.mass == 0 ? 0 : 1 / ap.mass;
	float invBmass = bp.mass == 0 ? 0 : 1 / bp.mass;

	float percent = 1;
	float slop	  = 0.001;
	float2 correction = m.normal * max( m.penetration - slop, 0.0f ) / (invAmass + invBmass) * percent;


	at.position += -correction * invAmass;
	bt.position +=  correction * invBmass;
}