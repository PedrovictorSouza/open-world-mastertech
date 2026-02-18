local IntroRules = {}

IntroRules.WhisperDialogueLines = {
    "Ola, explorador. Eu sou o Whisper.",
    "Voce caiu no ponto certo. Sua jornada comeca agora.",
    "Siga ate o outdoor para iniciar oficialmente a Expedicao.",
}

function IntroRules.getWhisperDialogueLines()
    local lines = {}
    for index, line in ipairs(IntroRules.WhisperDialogueLines) do
        lines[index] = line
    end

    return lines
end

return IntroRules
