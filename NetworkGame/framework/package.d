module framework;

public import framework.core;
public import framework.phone;
public import framework.components;
public import framework.player;
public import framework.screen;

import graphics.color;


import content;
import window.window;
import network.server;
import concurency.task;
import allocation;
import rendering;

struct PhoneAppConfig
{
	size_t numServices, numComponents;
	string name;
	string phoneResourceDir;

	WindowConfig windowConfig;
	ConcurencyConfig concurencyConfig;
	ServerConfig serverConfig;
	ContentConfig contentConfig;
	RenderConfig  renderConfig;
}


Application* createPhoneApp(A)(ref A al, PhoneAppConfig config)
{
	Application* g = al.allocate!Application(al, config.numServices, config.numComponents, config.name);

	auto loader  = al.allocate!AsyncContentLoader(al, config.contentConfig);
	g.addService(loader);

	auto windowComponent  = al.allocate!WindowComponent(config.windowConfig);
	auto taskComponent    = al.allocate!TaskComponent(al, config.concurencyConfig);
	auto networkComponent = al.allocate!NetworkComponent(al, config.serverConfig, config.phoneResourceDir);
	auto screenComponent  = al.allocate!ScreenComponent(al, 20);
	auto renderComponent  = al.allocate!RenderComponent(al, config.renderConfig);

	g.addComponent(renderComponent);
	g.addComponent(windowComponent);
	g.addComponent(taskComponent);
	g.addComponent(networkComponent);
	g.addComponent(screenComponent);

	version(RELOADING)
	{
		auto reloadingComponent = al.allocate!ReloadingComponent;
		g.addComponent(reloadingComponent);
	}

	auto players = al.allocate!(PlayerService!Player)(al, config.serverConfig.maxConnections, networkComponent.router);
	auto sensors = al.allocate!SensorService(al, config.serverConfig.maxConnections, networkComponent.router);
	
	g.addService(players);
	g.addService(sensors);

	return g;
}

struct Player 
{ 
	string name; 
	Color color; 
}
