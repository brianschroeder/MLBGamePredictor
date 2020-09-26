$ProgressPreference = 'Silent'
$ErrorActionPreference = 'SilentlyContinue'

$Games = (Invoke-WebRequest -UseBasicParsing  -Uri "http://statsapi.mlb.com/api/v1/schedule/games/?sportId=1&date=09/25/2020" | ConvertFrom-Json).Dates.Games.gamepk
$BaseballDataPoints = foreach ($game in $games) {
        $TeamStats = (Invoke-WebRequest -UseBasicParsing -Uri http://statsapi.mlb.com/api/v1/game/$Game/boxscore | ConvertFrom-Json)
        $HBA = New-Object -TypeName "System.Collections.ArrayList"
        $ABA = New-Object -TypeName "System.Collections.ArrayList"
        $AERA = New-Object -TypeName "System.Collections.ArrayList"
        $HERA = New-Object -TypeName "System.Collections.ArrayList"

        foreach ($Batter in $TeamStats.Teams.away.battingorder){
            $HBA += (Invoke-WebRequest -UseBasicParsing -Uri "https://statsapi.mlb.com/api/v1/people/$Batter/stats?stats=byDateRange&season=2020&group=hitting&startDate=10/20/1994&endDate=10/12/2028&leagueListId=mlb_milb" | ConvertFrom-Json).Stats.splits[0].stat.avg[1..3] -join ''    
        }
        
        foreach ($Batter in $TeamStats.Teams.home.battingorder) {
            $ABA += (Invoke-WebRequest -UseBasicParsing -Uri "https://statsapi.mlb.com/api/v1/people/$Batter/stats?stats=byDateRange&season=2020&group=hitting&startDate=10/20/1994&endDate=10/12/2028&leagueListId=mlb_milb" | ConvertFrom-Json).Stats.splits[0].stat.avg[1..3] -join '' 
        }

        foreach ($Pitcher in $TeamStats.Teams.away.pitchers[0]){
            $AERA += (Invoke-WebRequest -UseBasicParsing -Uri "https://statsapi.mlb.com/api/v1/people/$Pitcher/stats?stats=byDateRange&season=2020&group=pitching&startDate=10/20/1994&endDate=10/12/2028&leagueListId=mlb_milb" | ConvertFrom-Json).stats.splits[0].stat.ERA
        }
        
        foreach ($Pitcher in $TeamStats.Teams.home.pitchers[0]) {
            $HERA += (Invoke-WebRequest -UseBasicParsing -Uri "https://statsapi.mlb.com/api/v1/people/$Pitcher/stats?stats=byDateRange&season=2020&group=pitching&startDate=10/20/1994&endDate=10/12/2028&leagueListId=mlb_milb" | ConvertFrom-Json).stats.splits[0].stat.ERA
        }

        if (!($HBA -contains '000' -or $ABA -contains '000' -or $HERA[0] -contains $null -or $AERA[0] -contains $null)) {

            $HomeBattingAverage = (((($HBA | Measure-Object -Sum).sum/9000).toString("P") -replace '[.%]' , '')[0..2] -join '')
            $AwayBattingAverage = (((($ABA | Measure-Object -Sum).sum/9000).toString("P") -replace '[.%]' , '')[0..2] -join '')
            $HomeERA = $HERA[0] 
            $AwayERA = $AERA[0]

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

$BaseballPredictionTable = $BaseballDataPoints | Sort-Object HomeAdvantage -Descending 

foreach ($BattingAverage in $BaseballTable) {
    if ($BattingAverage.HomeBattingAverage -gt $BattingAverage.AwayBattingAverage -and $BattingAverage.HomeStartingPitcherERA -lt $BattingAverage.AwayStartingPitcherERA) {
        Write-Host "$($BattingAverage.HomeTeam) looks to have an advantage over $($BattingAverage.AwayTeam) by $($BattingAverage.HomeAdvantage)% at $($BattingAverage.StartTime)"  -ForegroundColor Green
        Write-Host `n"$($BattingAverage.HomeTeam) has a roster Batting Average advantage by $($BattingAverage.HomeBAVSAway)"
        Write-Host "$($BattingAverage.HomeTeam) has a starting pitcher ERA advantage by $($BattingAverage.HomeERAVSAway)%"`n

    }       

    if ($BattingAverage.AwayBattingAverage -gt $BattingAverage.HomeBattingAverage -and $BattingAverage.AwayStartingPitcherERA -lt $BattingAverage.HomeStartingPitcherERA) {
        Write-Host "$($BattingAverage.AwayTeam) looks to have an advantage over $($BattingAverage.HomeTeam) by $($BattingAverage.AwayAdvantage)% at $($BattingAverage.StartTime)" -ForegroundColor Green
        Write-Host `n"$($BattingAverage.AwayTeam) has a roster Batting Average advantage by $($BattingAverage.AwayBAVSHome)"
        Write-Host "$($BattingAverage.AwayTeam) has a starting pitcher ERA advantage by $($BattingAverage.AwayERAVSHome)%"`n
    }
}
