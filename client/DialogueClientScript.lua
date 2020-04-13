-- Get Roblox services
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local Players = game:GetService("Players");

local Player = Players.LocalPlayer;
local PlayerGui = Player:WaitForChild("PlayerGui");
local RemoteConnections = ReplicatedStorage:WaitForChild("DialogueMakerRemoteConnections",3);

-- Check if the DialogueMakerRemoteConnections folder was moved
if not RemoteConnections then
	error("[Dialogue Maker] Couldn't find the DialogueMakerRemoteConnections folder in the ReplicatedStorage.",0)
end;

-- Get themes
local Themes = script.Themes;
local DefaultTheme = RemoteConnections.GetDefaultTheme:InvokeServer();
local PlayerTalkingWithNPC = false;
local Events = {};

local function ReadDialogue(npc)
	
	if PlayerTalkingWithNPC then
		return;
	end;
	
	PlayerTalkingWithNPC = true;
	
	local DialogueContainer = npc.DialogueContainer;
	local DialogueSettings = DialogueContainer.Settings;
	local ThemeUsed = Themes[DefaultTheme];
	
	-- Check if the theme is different from the server theme
	if DialogueSettings.Theme.Value ~= "" then
		if Themes[DialogueSettings.Theme.Value] then
			ThemeUsed = Themes[DialogueSettings.Theme.Value];
		else
			warn("[Dialogue Maker] \""..DialogueSettings.Theme.Value.."\" wasn't a theme the client downloaded from the server, so we're going to use the default theme.");
		end;
	end;
	
	-- Freeze the player
	Player.Character.HumanoidRootPart.Anchored = true;
	
	-- Show the dialogue GUI to the player
	local DialogueGui = ThemeUsed:Clone();
	local DialoguePriority = "1";
	local RootDirectory = DialogueContainer["1"];
	local CurrentDirectory = RootDirectory;
	
	-- Show the dialouge to the player
	while PlayerTalkingWithNPC and game:GetService("RunService").Heartbeat:Wait() do
		
		if RemoteConnections.PlayerPassesCondition:InvokeServer(DialoguePriority) then
		
			local TargetDirectoryPath = DialoguePriority:split(".");
			local Attempts = #DialogueContainer:GetChildren();
			
			-- Move to the target directory
			for index, directory in ipairs(TargetDirectoryPath) do
				CurrentDirectory = CurrentDirectory.Dialogue[directory];
			end;
			
			-- Show the message to the player
			local ThemeDialogueContainer = DialogueGui.DialogueContainer;
			local LineTemplate = ThemeDialogueContainer.NPCTextContainerWithoutResponses.Line;
			local Message = "";
			
			DialogueGui.Parent = PlayerGui;
			
			local NPCTalking = true;
			local WaitingForResponse = true;
			
			-- Make the NPC stop talking if the player clicks the frame
			Events.DialogueClicked = ThemeDialogueContainer.InputBegan:Connect(function(input)
				
				-- Make sure the player clicked the frame
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					if NPCTalking then
						NPCTalking = false;
					else
						
						-- Check if there are any available responses
						if #CurrentDirectory.Responses:GetChildren() == 0 then
							WaitingForResponse = false;
						end;
						
					end;
				end;
				
			end);
			
			for _, letter in ipairs(CurrentDirectory.Message.Value:split("")) do
				
				-- Check if the player wants to skip their dialogue
				if not NPCTalking then
					
					-- Replace the incomplete dialogue with the full text
					ThemeDialogueContainer.NPCTextContainerWithoutResponses.Line.Text = CurrentDirectory.Message.Value;
					break;
					
				end;
				
				Message = Message..letter;
				ThemeDialogueContainer.NPCTextContainerWithoutResponses.Line.Text = Message;
				wait(.025);
				
			end;
			
			NPCTalking = false;
			
			while WaitingForResponse do
				game:GetService("RunService").Heartbeat:Wait();
			end;
			
			-- Check if there is more dialogue
			if #CurrentDirectory.Dialogue:GetChildren() ~= 0 then
				DialoguePriority = DialoguePriority..".1";
			else
				DialogueGui:Destroy();
				PlayerTalkingWithNPC = false;
			end;
			
		else
			
			local SplitPriority = DialoguePriority:split(".");
			SplitPriority[#SplitPriority] = SplitPriority[#SplitPriority] + 1;
			DialoguePriority = table.concat(".");
			
		end;
		
	end;
	
	-- Unfreeze the player
	Player.Character.HumanoidRootPart.Anchored = false;
	
end;

local NPCDialogue = RemoteConnections.GetNPCDialogue:InvokeServer()
	
print("[Dialogue Maker] Preparing dialogue that was received from the server...");

-- Iterate through every NPC in order to 
for _, npc in ipairs(NPCDialogue) do
	
	-- Make sure all NPCs aren't affected if this one doesn't load properly
	local success, msg = pcall(function()
		
		local DialogueSettings = npc.DialogueContainer.Settings;
		
		if DialogueSettings.SpeechBubbleEnabled.Value then
			
			if DialogueSettings.SpeechBubblePart.Value then
				
				if DialogueSettings.SpeechBubblePart.Value:IsA("Part") then
					
					-- Create a speech bubble
					local SpeechBubble = Instance.new("BillboardGui");
					SpeechBubble.Name = "SpeechBubble";
					SpeechBubble.Active = true;
					SpeechBubble.LightInfluence = 0;
					SpeechBubble.ResetOnSpawn = false;
					SpeechBubble.Size = UDim2.new(2.5,0,2.5,0);
					SpeechBubble.StudsOffset = Vector3.new(0,2,0);
					SpeechBubble.Adornee = DialogueSettings.SpeechBubblePart.Value;
					
					local SpeechBubbleButton = Instance.new("ImageButton");
					SpeechBubbleButton.BackgroundTransparency = 1;
					SpeechBubbleButton.BorderSizePixel = 0;
					SpeechBubbleButton.Name = "SpeechBubbleButton";
					SpeechBubbleButton.Size = UDim2.new(1,0,1,0);
					SpeechBubbleButton.Image = "rbxassetid://4883127463";
					SpeechBubbleButton.Parent = SpeechBubble;
					
					-- Listen if the player clicks the speech bubble
					SpeechBubbleButton.MouseButton1Click:Connect(function()
						
						ReadDialogue(npc)
						
					end);
					
					SpeechBubble.Parent = PlayerGui;
					
				else
					warn("[Dialogue Viewer] The SpeechBubblePart for "..npc.Name.." is not a Part.");
				end;
				
			end;
			
		end;
		
		if DialogueSettings.PromptRegionEnabled.Value then
			
			if DialogueSettings.PromptRegionPart.Value then
				
				if DialogueSettings.PromptRegionPart.Value:IsA("Part") then
					
					local PlayerTouched;
					DialogueSettings.PromptRegionPart.Value.Touched:Connect(function(part)
						
						-- Make sure our player touched it and not someone else
						local PlayerFromCharacter = Players:GetPlayerFromCharacter(part.Parent);
						if PlayerFromCharacter == Player then
							ReadDialogue(npc);
						end;
						
					end);
						
				else
					warn("[Dialogue Viewer] The PromptRegionPart for "..npc.Name.." is not a Part.");
				end;
				
			end;
			
		end;
		
		if DialogueSettings.ClickEnabled.Value then
			
			if DialogueSettings.ClickDetectorLocation.Value then
				
				if DialogueSettings.ClickDetectorLocation.Value:IsA("ClickDetector") then
					
					DialogueSettings.ClickDetectorLocation.Value.MouseClick:Connect(function()
						ReadDialogue(npc);
					end);
					
				else
					warn("[Dialogue Viewer] The ClickDetectorLocation for "..npc.Name.." is not a ClickDetector.");
				end;
				
			end;
			
		end;
		
	end)
	
end;

print("[Dialogue Maker] Finished preparing dialogue.");