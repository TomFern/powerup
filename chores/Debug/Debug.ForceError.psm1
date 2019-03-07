# Force an Error

function StepPre {
}

function StepProcess {
    Write-Error "[Debug.ForceError] Sending ERROR on StepProcess"
}

function StepNext {
    @{}
}

