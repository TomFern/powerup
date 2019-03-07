# Force an Exception


function StepPre {
}

function StepProcess {
    Throw "[Debug.ForceException] Sending ERROR on StepProcess"
}

function StepNext {
    @{}
}

