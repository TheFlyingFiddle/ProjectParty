module game.input.phone;

import collections.list;
import math;

//Need to decide where to store the phone values.
//This seems like a natural place so initially 
//this is were i will put it.
__gshared static List!Phone phones;

struct Phone 
{
	//Also need touch here but start with accelerometer and gyro.
	float3 accelerometer;
	float3 gyroscope;
}


//So bascially we need a way to add phones on connection 
//and remove them on dc. Apart from this we need a way to update
//the phones based on data gathered from the connection.
//The question is should the connection do this or should
//it be implemented in this class? 

//We also need a way to map from a phoneID to a phone. And a 
//way to accociate a connection with a phone. 

//Seeing that we need alot of stuff just to be able to use the phone
//And it is all network related i wonder if we should just put the phones
//in the network. Or alternativly in game? 