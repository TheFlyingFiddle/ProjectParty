module framework.factories;


import framework.core;
import framework.components;
import framework.screen;

import graphics.color;
import content;
import window.window;
import network.server;
import concurency.task;
import allocation;
import rendering;

struct DesktopAppConfig
{
	size_t numServices, numComponents;
	string name; 
	WindowConfig windowConfig;
	ConcurencyConfig concurencyConfig;
	ContentConfig contentConfig;
	RenderConfig renderConfig;
}

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

Application* createDesktopApp(A)(ref A al, DesktopAppConfig config)
{
	Application* app = al.allocate!Application(al, config.numServices, config.numComponents, config.name);
	auto loader	   = new AsyncContentLoader(al, config.contentConfig);
	app.addService(loader);

	auto window		= al.allocate!WindowComponent(config.windowConfig);
	auto task		= al.allocate!TaskComponent(al, config.concurencyConfig);
	auto screen		= al.allocate!ScreenComponent(al, 20);
	auto render     = al.allocate!RenderComponent(al, config.renderConfig);
	auto time		= al.allocate!TimerComponent(al, 100);

	app.addComponent(window);
	app.addComponent(task);
	app.addComponent(screen);
	app.addComponent(render);
	app.addComponent(time);

	version(RELOADING)
	{
		app.addComponent(al.allocate!ReloadingComponent);
	}

	return app;
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

	//Temp
	struct Player 
	{ 
		string name; 
		Color color; 
	}

	import framework.player;
	import framework.phone;

	auto players = al.allocate!(PlayerService!Player)(al, config.serverConfig.maxConnections, networkComponent.router);
	auto sensors = al.allocate!SensorService(al, config.serverConfig.maxConnections, networkComponent.router);

	g.addService(players);
	g.addService(sensors);

	return g;
}