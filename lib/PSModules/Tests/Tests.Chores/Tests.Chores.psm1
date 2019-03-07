# Unit test

Import-Power 'Pester'
Import-Power 'Chores' -Reload

$cfg1 = @{
    "name"= "TestChore";
    "description"= "Test Chore for Pester";
    "requires" = @{
        "arch" = "any";
        "elevated"= $false;
        "configs"=@('defaults');
    };
    "steps"=@("Debug.Nop","Debug.Nop");
}

$cfg2 = @{
    "name"= "TestChore";
    "description"= "Test Chore for Pester";
    "requires" = @{
        "arch" = "any";
        "elevated"= $false;
        "configs"=@('defaults');
    };
    "steps"=@("NONEXISTENTSTEP");
}

$cfg3 = @{
    "name"= "TestChore";
    "description"= "Test Chore for Pester";
    "requires" = @{
        "arch" = "any";
        "elevated"= $false;
        "configs"=@('defaults');
    };
    "steps"=@("Debug.Nop","Debug.ForceError","Debug.ForceError");
}
$cfg4 = @{
    "name"= "TestChore";
    "description"= "Test Chore for Pester";
    "requires" = @{
        "arch" = "any";
        "elevated"= $false;
        "configs"=@('defaults');
    };
    "steps"=@("Debug.Nop","Debug.ForceException");
}

Try {
    Close-Chore
}
Catch {
    ""
}

Describe "Chores" {
    It "Search-Chore #1" {
        {Search-Chore } | Should not Throw
    }
    It "New-Chore #1" {
        { New-Chore @{} } | Should Throw
    }
    It "New-Chore #2" {
        { New-Chore $cfg1 } | Should Not Throw
    }
    It "New-Chore #3" {
        { New-Chore $cfg2 } | Should Throw
    }
    It "New-Chore #4" {
        { New-Chore $cfg3 } | Should Not Throw
    }
    It "New-Chore #5" {
        { New-Chore $cfg4 } | Should Not Throw
    }
    It "Invoke-Chore #1" {
        $chore = New-Chore $cfg1 
        { Invoke-Chore $chore } | Should Not Throw
    }
    It "Invoke-Chore #2" {
        { Invoke-Chore @{} } | Should Throw
    }
    It "Invoke-Chore #3" {
        $chore = New-Chore $cfg3 
        { Invoke-Chore $chore } | Should Throw
    }
    It "Invoke-Chore #4" {
        $chore = New-Chore $cfg3 
        { Invoke-Chore $chore -OnError 'Continue' } | Should Not Throw
        $chore['Control']['ChoreWorkflow'] | Should Be 'STOP'
    }
    It "Invoke-Chore #5" {
        $chore = New-Chore $cfg4 
        { Invoke-Chore $chore -OnError 'Continue' } | Should Throw
        $chore['Control']['ChoreWorkflow'] | Should Be 'ERROR'
    }
    It "Invoke-Chore #6" {
        $chore = New-Chore $cfg1
        { Invoke-Chore $chore } | Should Not Throw
        $chore['Control']['ChoreWorkflow'] | Should Be 'STOP'
        { Invoke-Chore $chore -From 0 } | Should Not Throw
    }
    It "Invoke-Chore #7" {
        $chore = New-Chore $cfg1
        { Invoke-Chore $chore } | Should Not Throw
        $chore['Control']['ChoreWorkflow'] | Should Be 'STOP'
        { Invoke-Chore $chore -From 10 } | Should Throw
    }
    It "Invoke-Chore #8" {
        $chore = New-Chore $cfg3
        { Invoke-Chore $chore } | Should Throw
        $chore['Control']['ChoreWorkflow'] | Should Be 'ERROR'
        { Invoke-Chore $chore -From 0 } | Should Throw
    }
    It "User #1" {
        $chore = New-Chore $cfg1
        $chore['User']['Foo'] = 'Bar'
        { Invoke-Chore $chore } | Should Not Throw
        $chore['User']['Foo'] | Should be 'Bar'
    }
}


