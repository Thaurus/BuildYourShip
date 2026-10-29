-- Client entry point: builds the UI and starts every controller.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Client = script.Parent

local State = require(Client.ClientState)
local Sounds = require(Client.Sounds)
local UIKit = require(Client.UI.UIKit)
local HUD = require(Client.UI.HUD)
local InventoryPanel = require(Client.UI.InventoryPanel)
local ShopPanel = require(Client.UI.ShopPanel)
local MarketPanel = require(Client.UI.MarketPanel)
local Tutorial = require(Client.UI.Tutorial)
local CrewPanel = require(Client.UI.CrewPanel)
local StorePanel = require(Client.UI.StorePanel)
local BuildController = require(Client.Controllers.BuildController)
local OutlineController = require(Client.Controllers.OutlineController)
local EffectsController = require(Client.Controllers.EffectsController)
local NavigationController = require(Client.Controllers.NavigationController)
local HelmController = require(Client.Controllers.HelmController)
local PromptController = require(Client.Controllers.PromptController)
local CombatController = require(Client.Controllers.CombatController)
local QuestController = require(Client.Controllers.QuestController)
local WeatherController = require(Client.Controllers.WeatherController)
local SoundController = require(Client.Controllers.SoundController)
local ZoneController = require(Client.Controllers.ZoneController)

local screen = Instance.new("ScreenGui")
screen.Name = "BuildYourShipUI"
screen.ResetOnSpawn = false
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.IgnoreGuiInset = false
screen.Parent = player:WaitForChild("PlayerGui")

local ctx = {
	Screen = screen,
	State = State,
	Sounds = Sounds,
	Panels = {},
}

HUD.Init(ctx)
ctx.Invoke = HUD.Invoke
ctx.Panels.Inventory = InventoryPanel.Init(ctx)
ctx.Panels.Shop = ShopPanel.Init(ctx)
ctx.Panels.Market = MarketPanel.Init(ctx)
ctx.Panels.Crew = CrewPanel.Init(ctx)
ctx.Panels.Store = StorePanel.Init(ctx)
ctx.Panels.Tutorial = Tutorial.Init(ctx)
BuildController.Init(ctx)
OutlineController.Init()
EffectsController.Init(ctx)
NavigationController.Init(ctx)
HelmController.Init()
PromptController.Init()
CombatController.Init(ctx)
QuestController.Init(ctx)
WeatherController.Init(ctx)
SoundController.Init(ctx)
ZoneController.Init(ctx)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == Enum.KeyCode.I then
		ctx.Panels.Inventory.Toggle()
	elseif input.KeyCode == Enum.KeyCode.B then
		ctx.Invoke("ToggleBuild")
	elseif input.KeyCode == Enum.KeyCode.H then
		ctx.Invoke("BoardShip")
	elseif input.KeyCode == Enum.KeyCode.C then
		ctx.Panels.Crew.Toggle()
	elseif input.KeyCode == Enum.KeyCode.Escape then
		UIKit.CloseAll()
	end
end)
