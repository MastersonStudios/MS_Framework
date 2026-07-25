MSMeChatConfig = {}

-- Command and server-side validation
MSMeChatConfig.Command = 'me'
MSMeChatConfig.MaxLength = 160
MSMeChatConfig.CooldownMs = 1500
MSMeChatConfig.DisplayDistance = 18.0
MSMeChatConfig.ServerDistancePadding = 0.0
MSMeChatConfig.DisplayDurationMs = 7000
MSMeChatConfig.LogToConsole = true
MSMeChatConfig.AllowTextFormatting = false

-- 3D text above the speaking character
MSMeChatConfig.Show3DText = true
MSMeChatConfig.ShowAuthorName3D = true
MSMeChatConfig.RequireLineOfSight = false
MSMeChatConfig.HeadBone = 0x796E
MSMeChatConfig.HeightOffset = 0.38
MSMeChatConfig.LineHeight = 0.055
MSMeChatConfig.MessageSpacing = 0.035
MSMeChatConfig.CharactersPerLine = 42
MSMeChatConfig.MaxVisibleMessages = 3
MSMeChatConfig.TextScale = 0.30
MSMeChatConfig.MinimumTextScale = 0.22
MSMeChatConfig.TextFont = 1
MSMeChatConfig.TextColor = { 255, 226, 166, 255 }
MSMeChatConfig.FadeDurationMs = 1000

-- Optional entry in the normal chat window
MSMeChatConfig.ShowInChat = true
MSMeChatConfig.ChatColor = { 219, 176, 93 }
MSMeChatConfig.ChatPrefix = 'ME'
MSMeChatConfig.RegisterChatSuggestion = true
