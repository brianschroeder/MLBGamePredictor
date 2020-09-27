$ProgressPreference = 'Silent'

$GameDate = (Get-Date -UFormat "%m/%d/%Y").ToString()
$Games = (Invoke-WebRequest -UseBasicParsing  -Uri "http://statsapi.mlb.com/api/v1/schedule/games/?sportId=1&date=$GameDate" | ConvertFrom-Json).Dates.Games.gamepk
$BaseballDataPoints = foreach ($game in $games) {
        $TeamStats = (Invoke-WebRequest -UseBasicParsing -Uri http://statsapi.mlb.com/api/v1/game/$Game/boxscore | ConvertFrom-Json)
        $HomeBA = New-Object -TypeName "System.Collections.ArrayList"
        $AwayBA = New-Object -TypeName "System.Collections.ArrayList"
        $AwayERA = New-Object -TypeName "System.Collections.ArrayList"
        $HomeERA = New-Object -TypeName "System.Collections.ArrayList"

        foreach ($Batter in $TeamStats.Teams.away.battingorder){
            $HomeBA += (Invoke-WebRequest -UseBasicParsing -Uri "https://statsapi.mlb.com/api/v1/people/$Batter/stats?stats=byDateRange&season=2020&group=hitting&startDate=10/20/1994&endDate=10/12/2028&leagueListId=mlb_milb" | ConvertFrom-Json).Stats.splits[0].stat.avg[1..3] -join '' 
        }
        
        foreach ($Batter in $TeamStats.Teams.home.battingorder) {
            $AwayBA += (Invoke-WebRequest -UseBasicParsing -Uri "https://statsapi.mlb.com/api/v1/people/$Batter/stats?stats=byDateRange&season=2020&group=hitting&startDate=10/20/1994&endDate=10/12/2028&leagueListId=mlb_milb" | ConvertFrom-Json).Stats.splits[0].stat.avg[1..3] -join '' 
        }

        foreach ($Pitcher in $TeamStats.Teams.away.pitchers[0]){
            $AwayERA += (Invoke-WebRequest -UseBasicParsing -Uri "https://statsapi.mlb.com/api/v1/people/$Pitcher/stats?stats=byDateRange&season=2020&group=pitching&startDate=10/20/1994&endDate=10/12/2028&leagueListId=mlb_milb" | ConvertFrom-Json).stats.splits[0].stat.ERA
        }
        
        foreach ($Pitcher in $TeamStats.Teams.home.pitchers[0]) {
            $HomeERA += (Invoke-WebRequest -UseBasicParsing -Uri "https://statsapi.mlb.com/api/v1/people/$Pitcher/stats?stats=byDateRange&season=2020&group=pitching&startDate=10/20/1994&endDate=10/12/2028&leagueListId=mlb_milb" | ConvertFrom-Json).stats.splits[0].stat.ERA
        }

        if (!($HomeBA -contains '000' -or $AwayBA -contains '000' -or $HomeERA[0] -contains $null -or $AwayERA[0] -contains $null)) {

            $HomeBattingAverage = (((($HomeBA | Measure-Object -Sum).sum/9000).toString("P") -replace '[.%]' , '')[0..2] -join '')
            $AwayBattingAverage = (((($AwayBA | Measure-Object -Sum).sum/9000).toString("P") -replace '[.%]' , '')[0..2] -join '')
            $HomeERA = $HomeERA[0] 
            $AwayERA = $AwayERA[0]

            if ($HomeERA -lt $AwayERA) {
                $HomeERADifference = (1 - ($HomeERA/$AwayERA)).toString('P')
                $AwayERADifference = '-' + $HomeERADifference
            }

            if ($AwayERA -lt $HomeERA ) {
                $AwayERADifference = (1 - ($AwayERA/$HomeERA)).toString('P')
                $HomeERADifference = '-' + $AwayERADifference
            }

            if ($HomeBattingAverage -gt $AwayBattingAverage) {
                $HomeBattingAverageDifference = (1 - ($AwayBattingAverage/$HomeBattingAverage)).toString('P')
                $AwayBattingAverageDifference = '-' + $HomeBattingAverageDifference
            }

            if ($AwayBattingAverage -gt $HomeBattingAverage) {
                $AwayBattingAverageDifference = (1 - ($HomeBattingAverage/$AwayBattingAverage)).toString('P')
                $HomeBattingAverageDifference = '-' + $AwayBattingAverageDifference
            }

            [pscustomobject]@{
                HomeTeam = $TeamStats.Teams.home.team.name
                HomeBattingAverage = $HomeBattingAverage
                HomeStartingPitcherERA = $HomeERA
                HomeBAVSAway = $HomeBattingAverageDifference
                HomeERAVSAway = $HomeERADifference
                HomeAdvantage = [int]($HomeBattingAverageDifference -replace '%' -join '') + [int]($HomeERADifference -replace '%' -join '')
                AwayTeam = $TeamStats.Teams.away.team.name
                AwayBattingAverage = $AwayBattingAverage
                AwayStartingPitcherERA = $AwayERA 
                AwayBAVSHome = $AwayBattingAverageDifference
                AwayERAVSHome = $AwayERADifference
                AwayAdvantage = [int]($AwayBattingAverageDifference -replace '%' -join '') + [int]($AwayERADifference -replace '%' -join '')
                StartTime = (($TeamStats.info.value) | Select-String ' PM') -replace '[.]'
            }
        }
}

$GameDataHTML = New-Object -TypeName "System.Collections.ArrayList"
$GameDataHTML += "
<replace>
"
$BaseballDataPoints | Sort-Object HomeAdvantage -Descending

$GameDataHTML += "<h2><b>Home Teams</h2>"

foreach ($DataPoints in $BaseballDataPoints | Sort-Object HomeAdvantage -Descending ) {
    if ($DataPoints.HomeBattingAverage -gt $DataPoints.AwayBattingAverage -and $DataPoints.HomeStartingPitcherERA -lt $DataPoints.AwayStartingPitcherERA -and $DataPoints.HomeAdvantage -gt 27) {
        $GameDataHTML += "<h3><b>$($DataPoints.HomeTeam) look to have an advantage over $($DataPoints.AwayTeam) by $($DataPoints.HomeAdvantage)%</h3>"
        $GameDataHTML += "<h3><b>Start Time: $($DataPoints.StartTime)<h3>"
        $GameDataHTML += "<h4><b>$($DataPoints.HomeTeam) have a roster Batting Average advantage by $($DataPoints.HomeBAVSAway)</h4>" 
        $GameDataHTML += "<h4><b>$($DataPoints.HomeTeam) have a starting pitcher ERA advantage by $($DataPoints.HomeERAVSAway)</h4>" 
    }
}       

$GameDataHTML += "<h2><b>Away Teams</h2>"

foreach ($DataPoints in $BaseballDataPoints | Sort-Object AwayAdvantage -Descending ) {
    if ($DataPoints.AwayBattingAverage -gt $DataPoints.HomeBattingAverage -and $DataPoints.AwayStartingPitcherERA -lt $DataPoints.HomeStartingPitcherERA -and $DataPoints.AwayAdvantage -gt 27) {
        $GameDataHTML += "<h3><b>$($DataPoints.AwayTeam) look to have an advantage over $($DataPoints.HomeTeam) by $($DataPoints.AwayAdvantage)%</h3>"  
        $GameDataHTML += "<h3><b>Start Time: $($DataPoints.StartTime)<h3>"
        $GameDataHTML += "<h4><b>$($DataPoints.AwayTeam) have a roster Batting Average advantage by $($DataPoints.AwayBAVSHome)</h4>" 
        $GameDataHTML += "<h4><b>$($DataPoints.AwayTeam) have a starting pitcher ERA advantage by $($DataPoints.AwayERAVSHome)</h4>" 
    }
}

$HeaderDate = (Get-Date -UFormat "%A, %B %d, %Y")
$FooterDate = Get-Date -UFormat "%A, %B %d, %Y %T"
$GameDataHTML += "Last Updated: $FooterDate" 

if ($GameDataHTML -like '*advantage*') {
    $NewPredictions = ((Get-Content 'C:\inetpub\wwwroot\MLBGamePredictor\index.html') -replace '.+advantage.+' -replace '<replace>',"$GameDataHTML" -replace '.+<date>.+',"<date><b>$HeaderDate</b>") | Out-String
    New-Item -Name 'index.html' -Path C:\inetpub\wwwroot\MLBGamePredictor -ItemType File -Value $NewPredictions -Force | Out-Null
}
