[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$sampleRate = 22050
$outputDirectory = Join-Path (Split-Path -Parent $PSScriptRoot) "assets\audio"
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$legacyGameplayLoop = Join-Path $outputDirectory "gameplay_music.wav"
if (Test-Path -LiteralPath $legacyGameplayLoop) {
    Remove-Item -LiteralPath $legacyGameplayLoop -Force
}

function New-SampleBuffer {
    param(
        [Parameter(Mandatory)]
        [double]$Duration
    )

    return ,([double[]]::new(
        [Math]::Round($Duration * $script:sampleRate)
    ))
}

function Add-Chirp {
    param(
        [Parameter(Mandatory)]
        [double[]]$Samples,
        [Parameter(Mandatory)]
        [double]$Start,
        [Parameter(Mandatory)]
        [double]$Duration,
        [Parameter(Mandatory)]
        [double]$StartFrequency,
        [Parameter(Mandatory)]
        [double]$EndFrequency,
        [Parameter(Mandatory)]
        [double]$Amplitude,
        [double]$Attack = 0.01,
        [double]$Release = 0.08,
        [ValidateSet("sine", "triangle", "square")]
        [string]$Waveform = "sine"
    )

    $startIndex = [Math]::Round($Start * $script:sampleRate)
    $sampleCount = [Math]::Round($Duration * $script:sampleRate)
    $phase = 0.0
    for ($offset = 0; $offset -lt $sampleCount; $offset++) {
        $index = $startIndex + $offset
        if ($index -ge $Samples.Length) {
            break
        }

        $time = $offset / $script:sampleRate
        $progress = $time / $Duration
        $frequency = $StartFrequency + (
            ($EndFrequency - $StartFrequency) * $progress
        )
        $phase += 2.0 * [Math]::PI * $frequency / $script:sampleRate
        $wave = switch ($Waveform) {
            "triangle" {
                (2.0 / [Math]::PI) * [Math]::Asin([Math]::Sin($phase))
            }
            "square" {
                if ([Math]::Sin($phase) -ge 0.0) { 1.0 } else { -1.0 }
            }
            default {
                [Math]::Sin($phase)
            }
        }
        $envelope = [Math]::Min(
            1.0,
            [Math]::Min(
                $time / [Math]::Max($Attack, 0.0001),
                ($Duration - $time) / [Math]::Max($Release, 0.0001)
            )
        )
        $Samples[$index] += $wave * $Amplitude * [Math]::Max(0.0, $envelope)
    }
}

function Add-Noise {
    param(
        [Parameter(Mandatory)]
        [double[]]$Samples,
        [Parameter(Mandatory)]
        [double]$Start,
        [Parameter(Mandatory)]
        [double]$Duration,
        [Parameter(Mandatory)]
        [double]$Amplitude,
        [Parameter(Mandatory)]
        [uint32]$Seed,
        [double]$Release = 0.08
    )

    $startIndex = [Math]::Round($Start * $script:sampleRate)
    $sampleCount = [Math]::Round($Duration * $script:sampleRate)
    $state = [uint64]$Seed
    $smoothed = 0.0
    for ($offset = 0; $offset -lt $sampleCount; $offset++) {
        $index = $startIndex + $offset
        if ($index -ge $Samples.Length) {
            break
        }

        $state = (($state * 1664525) + 1013904223) -band 0xffffffffL
        $raw = ([double]$state / 2147483647.5) - 1.0
        $smoothed = ($smoothed * 0.72) + ($raw * 0.28)
        $time = $offset / $script:sampleRate
        $envelope = [Math]::Min(
            1.0,
            ($Duration - $time) / [Math]::Max($Release, 0.0001)
        )
        $Samples[$index] += (
            $smoothed * $Amplitude * [Math]::Max(0.0, $envelope)
        )
    }
}

function Add-PadTone {
    param(
        [Parameter(Mandatory)]
        [double[]]$Samples,
        [Parameter(Mandatory)]
        [double]$Frequency,
        [Parameter(Mandatory)]
        [double]$Amplitude,
        [double]$PhaseOffset = 0.0
    )

    $duration = $Samples.Length / $script:sampleRate
    $loopFrequency = [Math]::Round($Frequency * $duration) / $duration
    for ($index = 0; $index -lt $Samples.Length; $index++) {
        $time = $index / $script:sampleRate
        $Samples[$index] += (
            [Math]::Sin(
                2.0 * [Math]::PI * $loopFrequency * $time + $PhaseOffset
            ) * $Amplitude
        )
    }
}

function Add-Pluck {
    param(
        [Parameter(Mandatory)]
        [double[]]$Samples,
        [Parameter(Mandatory)]
        [double]$Start,
        [Parameter(Mandatory)]
        [double]$Duration,
        [Parameter(Mandatory)]
        [double]$Frequency,
        [Parameter(Mandatory)]
        [double]$Amplitude
    )

    Add-Chirp -Samples $Samples `
        -Start $Start `
        -Duration $Duration `
        -StartFrequency $Frequency `
        -EndFrequency ($Frequency * 1.004) `
        -Amplitude ($Amplitude * 0.70) `
        -Attack 0.004 `
        -Release ($Duration * 0.66) `
        -Waveform "sine"
    Add-Chirp -Samples $Samples `
        -Start $Start `
        -Duration ($Duration * 0.78) `
        -StartFrequency ($Frequency * 2.01) `
        -EndFrequency ($Frequency * 2.02) `
        -Amplitude ($Amplitude * 0.22) `
        -Attack 0.003 `
        -Release ($Duration * 0.58) `
        -Waveform "sine"
    Add-Chirp -Samples $Samples `
        -Start $Start `
        -Duration ($Duration * 0.54) `
        -StartFrequency ($Frequency * 3.98) `
        -EndFrequency ($Frequency * 4.0) `
        -Amplitude ($Amplitude * 0.08) `
        -Attack 0.002 `
        -Release ($Duration * 0.42) `
        -Waveform "sine"
}

function Write-MonoWav {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [double[]]$Samples
    )

    $peak = 0.0
    foreach ($sample in $Samples) {
        $peak = [Math]::Max($peak, [Math]::Abs($sample))
    }
    $normalization = if ($peak -gt 0.88) { 0.88 / $peak } else { 1.0 }
    $path = Join-Path $script:outputDirectory $Name
    $stream = [IO.File]::Open(
        $path,
        [IO.FileMode]::Create,
        [IO.FileAccess]::Write,
        [IO.FileShare]::None
    )
    try {
        $writer = [IO.BinaryWriter]::new($stream)
        $dataSize = $Samples.Length * 2
        $writer.Write([Text.Encoding]::ASCII.GetBytes("RIFF"))
        $writer.Write([int](36 + $dataSize))
        $writer.Write([Text.Encoding]::ASCII.GetBytes("WAVE"))
        $writer.Write([Text.Encoding]::ASCII.GetBytes("fmt "))
        $writer.Write([int]16)
        $writer.Write([int16]1)
        $writer.Write([int16]1)
        $writer.Write([int]$script:sampleRate)
        $writer.Write([int]($script:sampleRate * 2))
        $writer.Write([int16]2)
        $writer.Write([int16]16)
        $writer.Write([Text.Encoding]::ASCII.GetBytes("data"))
        $writer.Write([int]$dataSize)
        foreach ($sample in $Samples) {
            $scaled = [Math]::Round(
                [Math]::Max(
                    -1.0,
                    [Math]::Min(1.0, $sample * $normalization)
                ) * 32767.0
            )
            $writer.Write([int16]$scaled)
        }
        $writer.Flush()
    }
    finally {
        $stream.Dispose()
    }
}

function New-Effect {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [double]$Duration,
        [Parameter(Mandatory)]
        [array]$Tones,
        [array]$Noises = @()
    )

    $samples = New-SampleBuffer -Duration $Duration
    foreach ($tone in $Tones) {
        Add-Chirp -Samples $samples `
            -Start $tone.Start `
            -Duration $tone.Duration `
            -StartFrequency $tone.StartFrequency `
            -EndFrequency $tone.EndFrequency `
            -Amplitude $tone.Amplitude `
            -Attack $tone.Attack `
            -Release $tone.Release `
            -Waveform $tone.Waveform
    }
    foreach ($noise in $Noises) {
        Add-Noise -Samples $samples `
            -Start $noise.Start `
            -Duration $noise.Duration `
            -Amplitude $noise.Amplitude `
            -Seed $noise.Seed `
            -Release $noise.Release
    }
    Write-MonoWav -Name $Name -Samples $samples
}

$effects = @(
    @{
        Name = "ui_feedback.wav"
        Duration = 0.18
        Tones = @(
            @{
                Start = 0.0; Duration = 0.16
                StartFrequency = 620.0; EndFrequency = 860.0
                Amplitude = 0.34; Attack = 0.005; Release = 0.08
                Waveform = "triangle"
            }
        )
    },
    @{
        Name = "tongue_launch.wav"
        Duration = 0.28
        Tones = @(
            @{
                Start = 0.0; Duration = 0.24
                StartFrequency = 190.0; EndFrequency = 520.0
                Amplitude = 0.42; Attack = 0.004; Release = 0.09
                Waveform = "sine"
            },
            @{
                Start = 0.02; Duration = 0.17
                StartFrequency = 430.0; EndFrequency = 760.0
                Amplitude = 0.16; Attack = 0.004; Release = 0.07
                Waveform = "triangle"
            }
        )
        Noises = @(
            @{
                Start = 0.0; Duration = 0.14; Amplitude = 0.08
                Seed = 101; Release = 0.1
            }
        )
    },
    @{
        Name = "tongue_hit.wav"
        Duration = 0.24
        Tones = @(
            @{
                Start = 0.0; Duration = 0.20
                StartFrequency = 330.0; EndFrequency = 260.0
                Amplitude = 0.46; Attack = 0.002; Release = 0.11
                Waveform = "triangle"
            },
            @{
                Start = 0.015; Duration = 0.13
                StartFrequency = 720.0; EndFrequency = 520.0
                Amplitude = 0.16; Attack = 0.002; Release = 0.08
                Waveform = "sine"
            }
        )
    },
    @{
        Name = "tongue_miss.wav"
        Duration = 0.38
        Tones = @(
            @{
                Start = 0.0; Duration = 0.34
                StartFrequency = 390.0; EndFrequency = 130.0
                Amplitude = 0.28; Attack = 0.008; Release = 0.12
                Waveform = "sine"
            }
        )
        Noises = @(
            @{
                Start = 0.02; Duration = 0.26; Amplitude = 0.11
                Seed = 202; Release = 0.13
            }
        )
    },
    @{
        Name = "struggle_tap.wav"
        Duration = 0.12
        Tones = @(
            @{
                Start = 0.0; Duration = 0.10
                StartFrequency = 185.0; EndFrequency = 245.0
                Amplitude = 0.30; Attack = 0.002; Release = 0.055
                Waveform = "square"
            }
        )
    },
    @{
        Name = "swallow.wav"
        Duration = 0.46
        Tones = @(
            @{
                Start = 0.0; Duration = 0.40
                StartFrequency = 310.0; EndFrequency = 92.0
                Amplitude = 0.50; Attack = 0.004; Release = 0.16
                Waveform = "sine"
            },
            @{
                Start = 0.08; Duration = 0.26
                StartFrequency = 160.0; EndFrequency = 230.0
                Amplitude = 0.22; Attack = 0.01; Release = 0.12
                Waveform = "triangle"
            }
        )
    },
    @{
        Name = "digest.wav"
        Duration = 0.58
        Tones = @(
            @{
                Start = 0.00; Duration = 0.22
                StartFrequency = 262.0; EndFrequency = 262.0
                Amplitude = 0.25; Attack = 0.005; Release = 0.12
                Waveform = "triangle"
            },
            @{
                Start = 0.13; Duration = 0.25
                StartFrequency = 330.0; EndFrequency = 330.0
                Amplitude = 0.27; Attack = 0.005; Release = 0.13
                Waveform = "triangle"
            },
            @{
                Start = 0.28; Duration = 0.27
                StartFrequency = 440.0; EndFrequency = 440.0
                Amplitude = 0.29; Attack = 0.005; Release = 0.16
                Waveform = "triangle"
            }
        )
    },
    @{
        Name = "spit.wav"
        Duration = 0.42
        Tones = @(
            @{
                Start = 0.0; Duration = 0.36
                StartFrequency = 140.0; EndFrequency = 430.0
                Amplitude = 0.38; Attack = 0.004; Release = 0.11
                Waveform = "sine"
            }
        )
        Noises = @(
            @{
                Start = 0.0; Duration = 0.22; Amplitude = 0.09
                Seed = 303; Release = 0.12
            }
        )
    },
    @{
        Name = "growth.wav"
        Duration = 0.88
        Tones = @(
            @{
                Start = 0.00; Duration = 0.35
                StartFrequency = 220.0; EndFrequency = 330.0
                Amplitude = 0.26; Attack = 0.01; Release = 0.18
                Waveform = "sine"
            },
            @{
                Start = 0.20; Duration = 0.40
                StartFrequency = 330.0; EndFrequency = 440.0
                Amplitude = 0.29; Attack = 0.01; Release = 0.20
                Waveform = "sine"
            },
            @{
                Start = 0.43; Duration = 0.42
                StartFrequency = 440.0; EndFrequency = 660.0
                Amplitude = 0.31; Attack = 0.01; Release = 0.22
                Waveform = "triangle"
            }
        )
    },
    @{
        Name = "damage.wav"
        Duration = 0.48
        Tones = @(
            @{
                Start = 0.0; Duration = 0.43
                StartFrequency = 135.0; EndFrequency = 72.0
                Amplitude = 0.52; Attack = 0.002; Release = 0.18
                Waveform = "square"
            }
        )
        Noises = @(
            @{
                Start = 0.0; Duration = 0.25; Amplitude = 0.16
                Seed = 404; Release = 0.15
            }
        )
    },
    @{
        Name = "discovery.wav"
        Duration = 0.78
        Tones = @(
            @{
                Start = 0.00; Duration = 0.31
                StartFrequency = 523.0; EndFrequency = 659.0
                Amplitude = 0.24; Attack = 0.008; Release = 0.17
                Waveform = "triangle"
            },
            @{
                Start = 0.18; Duration = 0.34
                StartFrequency = 659.0; EndFrequency = 784.0
                Amplitude = 0.26; Attack = 0.008; Release = 0.18
                Waveform = "triangle"
            },
            @{
                Start = 0.38; Duration = 0.37
                StartFrequency = 784.0; EndFrequency = 1046.0
                Amplitude = 0.23; Attack = 0.008; Release = 0.20
                Waveform = "sine"
            }
        )
    },
    @{
        Name = "challenge_complete.wav"
        Duration = 0.92
        Tones = @(
            @{
                Start = 0.00; Duration = 0.28
                StartFrequency = 294.0; EndFrequency = 370.0
                Amplitude = 0.23; Attack = 0.006; Release = 0.14
                Waveform = "triangle"
            },
            @{
                Start = 0.17; Duration = 0.30
                StartFrequency = 370.0; EndFrequency = 440.0
                Amplitude = 0.25; Attack = 0.006; Release = 0.15
                Waveform = "triangle"
            },
            @{
                Start = 0.35; Duration = 0.33
                StartFrequency = 440.0; EndFrequency = 587.0
                Amplitude = 0.27; Attack = 0.006; Release = 0.17
                Waveform = "triangle"
            },
            @{
                Start = 0.55; Duration = 0.34
                StartFrequency = 587.0; EndFrequency = 740.0
                Amplitude = 0.25; Attack = 0.006; Release = 0.19
                Waveform = "sine"
            }
        )
    }
)

$productionEffects = @(
    @{
        Name = "pursuit_alert.wav"
        Duration = 0.42
        Tones = @(
            @{
                Start = 0.00; Duration = 0.20
                StartFrequency = 392.0; EndFrequency = 430.0
                Amplitude = 0.34; Attack = 0.006; Release = 0.10
                Waveform = "triangle"
            },
            @{
                Start = 0.19; Duration = 0.21
                StartFrequency = 523.0; EndFrequency = 590.0
                Amplitude = 0.38; Attack = 0.006; Release = 0.12
                Waveform = "triangle"
            }
        )
    },
    @{
        Name = "pursuit_escape.wav"
        Duration = 0.38
        Tones = @(
            @{
                Start = 0.0; Duration = 0.35
                StartFrequency = 659.0; EndFrequency = 420.0
                Amplitude = 0.34; Attack = 0.005; Release = 0.18
                Waveform = "sine"
            }
        )
    },
    @{
        Name = "net_warning.wav"
        Duration = 0.36
        Tones = @(
            @{
                Start = 0.0; Duration = 0.32
                StartFrequency = 330.0; EndFrequency = 560.0
                Amplitude = 0.31; Attack = 0.004; Release = 0.15
                Waveform = "triangle"
            }
        )
        Noises = @(
            @{
                Start = 0.0; Duration = 0.28; Amplitude = 0.14
                Seed = 505; Release = 0.15
            }
        )
    },
    @{
        Name = "flashlight_warning.wav"
        Duration = 0.34
        Tones = @(
            @{
                Start = 0.0; Duration = 0.30
                StartFrequency = 880.0; EndFrequency = 1040.0
                Amplitude = 0.28; Attack = 0.008; Release = 0.14
                Waveform = "sine"
            },
            @{
                Start = 0.08; Duration = 0.22
                StartFrequency = 1175.0; EndFrequency = 990.0
                Amplitude = 0.15; Attack = 0.004; Release = 0.12
                Waveform = "sine"
            }
        )
    },
    @{
        Name = "watchdog_lunge.wav"
        Duration = 0.32
        Tones = @(
            @{
                Start = 0.0; Duration = 0.28
                StartFrequency = 185.0; EndFrequency = 92.0
                Amplitude = 0.43; Attack = 0.003; Release = 0.14
                Waveform = "triangle"
            }
        )
        Noises = @(
            @{
                Start = 0.0; Duration = 0.20; Amplitude = 0.11
                Seed = 606; Release = 0.12
            }
        )
    },
    @{
        Name = "trap_deploy.wav"
        Duration = 0.30
        Tones = @(
            @{
                Start = 0.0; Duration = 0.27
                StartFrequency = 240.0; EndFrequency = 510.0
                Amplitude = 0.37; Attack = 0.003; Release = 0.13
                Waveform = "square"
            }
        )
        Noises = @(
            @{
                Start = 0.02; Duration = 0.18; Amplitude = 0.12
                Seed = 707; Release = 0.10
            }
        )
    },
    @{
        Name = "trap_trigger.wav"
        Duration = 0.32
        Tones = @(
            @{
                Start = 0.0; Duration = 0.29
                StartFrequency = 620.0; EndFrequency = 230.0
                Amplitude = 0.42; Attack = 0.002; Release = 0.14
                Waveform = "triangle"
            }
        )
        Noises = @(
            @{
                Start = 0.0; Duration = 0.18; Amplitude = 0.11
                Seed = 808; Release = 0.10
            }
        )
    },
    @{
        Name = "roadblock_deploy.wav"
        Duration = 0.36
        Tones = @(
            @{
                Start = 0.0; Duration = 0.33
                StartFrequency = 155.0; EndFrequency = 112.0
                Amplitude = 0.42; Attack = 0.003; Release = 0.16
                Waveform = "triangle"
            }
        )
        Noises = @(
            @{
                Start = 0.0; Duration = 0.24; Amplitude = 0.15
                Seed = 909; Release = 0.14
            }
        )
    },
    @{
        Name = "roadblock_hit.wav"
        Duration = 0.20
        Tones = @(
            @{
                Start = 0.0; Duration = 0.17
                StartFrequency = 175.0; EndFrequency = 132.0
                Amplitude = 0.46; Attack = 0.002; Release = 0.10
                Waveform = "triangle"
            }
        )
        Noises = @(
            @{
                Start = 0.0; Duration = 0.12; Amplitude = 0.14
                Seed = 1001; Release = 0.08
            }
        )
    },
    @{
        Name = "roadblock_break.wav"
        Duration = 0.42
        Tones = @(
            @{
                Start = 0.0; Duration = 0.38
                StartFrequency = 190.0; EndFrequency = 78.0
                Amplitude = 0.45; Attack = 0.002; Release = 0.18
                Waveform = "triangle"
            }
        )
        Noises = @(
            @{
                Start = 0.0; Duration = 0.31; Amplitude = 0.20
                Seed = 1102; Release = 0.18
            }
        )
    },
    @{
        Name = "power_activate.wav"
        Duration = 0.44
        Tones = @(
            @{
                Start = 0.0; Duration = 0.40
                StartFrequency = 392.0; EndFrequency = 659.0
                Amplitude = 0.35; Attack = 0.006; Release = 0.18
                Waveform = "sine"
            },
            @{
                Start = 0.12; Duration = 0.27
                StartFrequency = 784.0; EndFrequency = 1046.0
                Amplitude = 0.16; Attack = 0.006; Release = 0.15
                Waveform = "triangle"
            }
        )
    },
    @{
        Name = "shield_pop.wav"
        Duration = 0.30
        Tones = @(
            @{
                Start = 0.0; Duration = 0.27
                StartFrequency = 760.0; EndFrequency = 240.0
                Amplitude = 0.38; Attack = 0.002; Release = 0.14
                Waveform = "sine"
            }
        )
        Noises = @(
            @{
                Start = 0.0; Duration = 0.15; Amplitude = 0.16
                Seed = 1203; Release = 0.10
            }
        )
    },
    @{
        Name = "room_travel.wav"
        Duration = 0.42
        Tones = @(
            @{
                Start = 0.0; Duration = 0.38
                StartFrequency = 220.0; EndFrequency = 580.0
                Amplitude = 0.31; Attack = 0.008; Release = 0.19
                Waveform = "sine"
            },
            @{
                Start = 0.10; Duration = 0.28
                StartFrequency = 330.0; EndFrequency = 760.0
                Amplitude = 0.13; Attack = 0.008; Release = 0.16
                Waveform = "triangle"
            }
        )
    },
    @{
        Name = "destruction.wav"
        Duration = 0.55
        Tones = @(
            @{
                Start = 0.0; Duration = 0.50
                StartFrequency = 125.0; EndFrequency = 58.0
                Amplitude = 0.48; Attack = 0.002; Release = 0.22
                Waveform = "triangle"
            }
        )
        Noises = @(
            @{
                Start = 0.0; Duration = 0.42; Amplitude = 0.24
                Seed = 1304; Release = 0.24
            }
        )
    },
    @{
        Name = "clue_found.wav"
        Duration = 0.48
        Tones = @(
            @{
                Start = 0.00; Duration = 0.24
                StartFrequency = 523.0; EndFrequency = 523.0
                Amplitude = 0.27; Attack = 0.004; Release = 0.16
                Waveform = "triangle"
            },
            @{
                Start = 0.13; Duration = 0.25
                StartFrequency = 659.0; EndFrequency = 659.0
                Amplitude = 0.28; Attack = 0.004; Release = 0.17
                Waveform = "triangle"
            },
            @{
                Start = 0.27; Duration = 0.20
                StartFrequency = 784.0; EndFrequency = 784.0
                Amplitude = 0.25; Attack = 0.004; Release = 0.14
                Waveform = "sine"
            }
        )
    },
    @{
        Name = "achievement.wav"
        Duration = 0.62
        Tones = @(
            @{
                Start = 0.00; Duration = 0.28
                StartFrequency = 392.0; EndFrequency = 392.0
                Amplitude = 0.25; Attack = 0.004; Release = 0.18
                Waveform = "triangle"
            },
            @{
                Start = 0.14; Duration = 0.30
                StartFrequency = 494.0; EndFrequency = 494.0
                Amplitude = 0.27; Attack = 0.004; Release = 0.19
                Waveform = "triangle"
            },
            @{
                Start = 0.30; Duration = 0.30
                StartFrequency = 784.0; EndFrequency = 784.0
                Amplitude = 0.28; Attack = 0.004; Release = 0.20
                Waveform = "sine"
            }
        )
    },
    @{
        Name = "growth_major.wav"
        Duration = 0.70
        Tones = @(
            @{
                Start = 0.0; Duration = 0.66
                StartFrequency = 165.0; EndFrequency = 660.0
                Amplitude = 0.41; Attack = 0.012; Release = 0.25
                Waveform = "triangle"
            },
            @{
                Start = 0.22; Duration = 0.44
                StartFrequency = 330.0; EndFrequency = 990.0
                Amplitude = 0.17; Attack = 0.008; Release = 0.22
                Waveform = "sine"
            }
        )
    },
    @{
        Name = "epilogue_open.wav"
        Duration = 0.58
        Tones = @(
            @{
                Start = 0.00; Duration = 0.29
                StartFrequency = 262.0; EndFrequency = 262.0
                Amplitude = 0.24; Attack = 0.005; Release = 0.19
                Waveform = "triangle"
            },
            @{
                Start = 0.16; Duration = 0.31
                StartFrequency = 330.0; EndFrequency = 330.0
                Amplitude = 0.25; Attack = 0.005; Release = 0.20
                Waveform = "triangle"
            },
            @{
                Start = 0.32; Duration = 0.24
                StartFrequency = 392.0; EndFrequency = 523.0
                Amplitude = 0.23; Attack = 0.005; Release = 0.17
                Waveform = "sine"
            }
        )
    },
    @{
        Name = "epilogue_return.wav"
        Duration = 0.34
        Tones = @(
            @{
                Start = 0.0; Duration = 0.31
                StartFrequency = 523.0; EndFrequency = 392.0
                Amplitude = 0.30; Attack = 0.006; Release = 0.17
                Waveform = "sine"
            }
        )
    }
)
$effects += $productionEffects

foreach ($effect in $effects) {
    New-Effect @effect
}

function New-MusicLoop {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [array]$Chords,
        [Parameter(Mandatory)]
        [array]$Arpeggio,
        [Parameter(Mandatory)]
        [double]$PulseFrequency
    )

    $duration = 4.0
    $samples = New-SampleBuffer -Duration $duration
    $chordDuration = $duration / $Chords.Count
    for ($chordIndex = 0; $chordIndex -lt $Chords.Count; $chordIndex++) {
        $chordStart = $chordIndex * $chordDuration
        foreach ($frequency in $Chords[$chordIndex]) {
            Add-Chirp -Samples $samples `
                -Start $chordStart `
                -Duration $chordDuration `
                -StartFrequency $frequency `
                -EndFrequency $frequency `
                -Amplitude 0.055 `
                -Attack 0.12 `
                -Release 0.24 `
                -Waveform "sine"
        }
    }
    for ($step = 0; $step -lt 8; $step++) {
        $frequency = $Arpeggio[$step % $Arpeggio.Count]
        Add-Pluck -Samples $samples `
            -Start ($step * 0.5) `
            -Duration 0.42 `
            -Frequency $frequency `
            -Amplitude 0.15
    }
    for ($pulse = 0; $pulse -lt 2; $pulse++) {
        Add-Chirp -Samples $samples `
            -Start ($pulse * 2.0) `
            -Duration 0.34 `
            -StartFrequency $PulseFrequency `
            -EndFrequency ($PulseFrequency * 0.68) `
            -Amplitude 0.10 `
            -Attack 0.004 `
            -Release 0.23 `
            -Waveform "sine"
    }
    Write-MonoWav -Name $Name -Samples $samples
}

New-MusicLoop `
    -Name "menu_music.wav" `
    -Chords @(
        @(130.81, 164.81, 196.00),
        @(110.00, 130.81, 164.81),
        @(87.31, 110.00, 130.81),
        @(98.00, 123.47, 146.83)
    ) `
    -Arpeggio @(261.63, 329.63, 392.00, 493.88, 392.00, 329.63) `
    -PulseFrequency 98.0

New-MusicLoop `
    -Name "gameplay_day.wav" `
    -Chords @(
        @(110.00, 146.83, 174.61),
        @(98.00, 130.81, 164.81),
        @(87.31, 130.81, 174.61),
        @(98.00, 146.83, 196.00)
    ) `
    -Arpeggio @(220.00, 293.66, 349.23, 440.00, 349.23, 293.66) `
    -PulseFrequency 82.41

New-MusicLoop `
    -Name "gameplay_night.wav" `
    -Chords @(
        @(82.41, 110.00, 130.81),
        @(73.42, 98.00, 123.47),
        @(65.41, 98.00, 130.81),
        @(73.42, 110.00, 146.83)
    ) `
    -Arpeggio @(440.00, 523.25, 659.25, 587.33, 523.25, 440.00) `
    -PulseFrequency 65.41

New-MusicLoop `
    -Name "pursuit_music.wav" `
    -Chords @(
        @(73.42, 98.00, 116.54),
        @(82.41, 110.00, 130.81),
        @(73.42, 98.00, 123.47),
        @(65.41, 92.50, 110.00)
    ) `
    -Arpeggio @(293.66, 349.23, 440.00, 392.00, 349.23, 466.16) `
    -PulseFrequency 61.74

New-MusicLoop `
    -Name "epilogue_music.wav" `
    -Chords @(
        @(130.81, 164.81, 196.00),
        @(146.83, 174.61, 220.00),
        @(164.81, 196.00, 246.94),
        @(123.47, 164.81, 196.00)
    ) `
    -Arpeggio @(523.25, 659.25, 783.99, 659.25, 587.33, 493.88) `
    -PulseFrequency 98.0

function New-AmbienceLoop {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [bool]$Night
    )

    $duration = 4.0
    $samples = New-SampleBuffer -Duration $duration
    Add-PadTone -Samples $samples -Frequency 49.0 -Amplitude 0.035
    Add-PadTone `
        -Samples $samples `
        -Frequency $(if ($Night) { 73.5 } else { 65.5 }) `
        -Amplitude 0.022 `
        -PhaseOffset 1.2
    Add-PadTone -Samples $samples -Frequency 0.5 -Amplitude 0.018

    $passes = if ($Night) {
        @(
            @{ Start = 1.1; From = 82.0; To = 115.0; Amplitude = 0.045 },
            @{ Start = 2.7; From = 98.0; To = 70.0; Amplitude = 0.038 }
        )
    }
    else {
        @(
            @{ Start = 0.7; From = 92.0; To = 142.0; Amplitude = 0.052 },
            @{ Start = 2.5; From = 128.0; To = 78.0; Amplitude = 0.048 }
        )
    }
    foreach ($pass in $passes) {
        Add-Chirp -Samples $samples `
            -Start $pass.Start `
            -Duration 1.15 `
            -StartFrequency $pass.From `
            -EndFrequency $pass.To `
            -Amplitude $pass.Amplitude `
            -Attack 0.25 `
            -Release 0.34 `
            -Waveform "sine"
    }

    if ($Night) {
        foreach ($start in @(0.9, 1.15, 3.1, 3.35)) {
            Add-Chirp -Samples $samples `
                -Start $start `
                -Duration 0.12 `
                -StartFrequency 1680.0 `
                -EndFrequency 1840.0 `
                -Amplitude 0.035 `
                -Attack 0.006 `
                -Release 0.06 `
                -Waveform "triangle"
        }
    }
    else {
        foreach ($start in @(1.8, 3.25)) {
            Add-Chirp -Samples $samples `
                -Start $start `
                -Duration 0.34 `
                -StartFrequency 880.0 `
                -EndFrequency 1210.0 `
                -Amplitude 0.038 `
                -Attack 0.02 `
                -Release 0.16 `
                -Waveform "sine"
        }
    }
    Write-MonoWav -Name $Name -Samples $samples
}

New-AmbienceLoop -Name "city_day.wav" -Night $false
New-AmbienceLoop -Name "city_night.wav" -Night $true

$generatedFiles = Get-ChildItem -LiteralPath $outputDirectory -Filter "*.wav"
$totalBytes = ($generatedFiles | Measure-Object -Property Length -Sum).Sum
Write-Host (
    "Generated {0} original audio files ({1:N1} KiB) in {2}." -f
    $generatedFiles.Count,
    ($totalBytes / 1KB),
    $outputDirectory
)
