function New-TCPClient {
    New-Object -TypeName System.Net.Sockets.TcpClient
}

function Connect-TCPClient {
    param (
        [Parameter(Mandatory,ValueFromPipeline)]$Client,

        [Parameter(Mandatory)]
        [string]
        $ComputerName,

        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [Int16]
        $Port,

        [Switch]$Passthru
    )
    process {
        $Client.Connect($ComputerName, $Port)
        if ($Passthru) { $Client }
    }
}

function New-TCPClientStream {
    param (
        [Parameter(Mandatory,ValueFromPipeline)]$Client,
        
        [TimeSpan]$Timeout = [System.Threading.Timeout]::InfiniteTimeSpan

    )
    process {
        $Stream = $Client.GetStream()        
        
        $Stream.ReadTimeout = [System.Threading.Timeout]::Infinite
        if ($Timeout -ne [System.Threading.Timeout]::InfiniteTimeSpan) {
            $Stream.ReadTimeout = $Timeout.TotalMilliseconds
        }

        $Stream
    }
}

function Write-TCPStream {
    param(
        [Parameter(Mandatory)]$Client,
        [Parameter(Mandatory)]$Stream,
        [Parameter(ValueFromPipeline,Mandatory)][string[]]$Data,
        [System.Text.Encoding]$Encoding = [System.Text.Encoding]::ASCII,
        $SecondsToSleepBeforeReading = 1
    )
    process {
        $StreamWriter = New-Object -Type System.IO.StreamWriter -ArgumentList $Stream, $Encoding, $Client.SendBufferSize, $true

        # send all the input data
        foreach ($Line in $Data) {
            $StreamWriter.WriteLine($Line)
        }
        $StreamWriter.Flush()
        Start-Sleep -Seconds $SecondsToSleepBeforeReading
        $StreamWriter.Dispose()
    }
}

function Read-TCPStream {
    param (
        [Parameter(Mandatory)]$Client,
        [Parameter(Mandatory,ValueFromPipeline)]$Stream,
        [System.Text.Encoding]$Encoding = [System.Text.Encoding]::ASCII
    )
    process {        

        $Result = ''
        $Buffer = New-Object -TypeName System.Byte[] -ArgumentList $Client.ReceiveBufferSize
        do {
            try {
                $ByteCount = $Stream.Read($Buffer, 0, $Buffer.Length)
            } catch [System.IO.IOException] {
                $ByteCount = 0
            }
            if ($ByteCount -gt 0) {
                $Result += $Encoding.GetString($Buffer, 0, $ByteCount)
            }
        } while ($Stream.DataAvailable) 

        Write-Output $Result
    }
}

function Disconnect-TCPClient {
    param (
        [Parameter(Mandatory,ValueFromPipeline)]$Client
    )    

    $Client.Client.Shutdown('Send')
}

function Test-Zebra {
    $Client = New-TCPClient

    $Stream = $Client | 
    Connect-TCPClient -ComputerName GradMickey -Port 9100 -Passthru | 
    New-TCPClientStream

    "^XA^HH^XZ" | Write-TCPStream -Client $Client -Stream $Stream

    $Stream | Read-TCPStream -Client $Client

    $Client | Disconnect-TCPClient

    #Send-NetworkData -Data "^XA^HH^XZ" -Computer $ComputerName -Port 9100
}

function Test-Zebra2 {
    "^XA^HH^XZ","^XA^HH^XZ" | Send-TCPClientData -ComputerName GradMickey -Port 9100
}

function Send-TCPClientData {
    param (
        [Parameter(Mandatory)]
        [string]
        $ComputerName,

        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [Int16]
        $Port,

        [Parameter(Mandatory)]
        [string[]]
        $Data,

        [System.Text.Encoding]
        $Encoding = [System.Text.Encoding]::ASCII,

        [TimeSpan]
        $Timeout = [System.Threading.Timeout]::InfiniteTimeSpan,

        [Switch]$NoReply
    )

    $Client = New-TCPClient

    $Stream = $Client | 
    Connect-TCPClient -ComputerName $ComputerName -Port $Port -Passthru | 
    New-TCPClientStream -Timeout $Timeout

    $Data | Write-TCPStream -Client $Client -Stream $Stream -Encoding $Encoding

    if (-not $NoReply) {
        $Stream | Read-TCPStream -Client $Client -Encoding $Encoding
    }

    $Client | Disconnect-TCPClient

    $Stream.Dispose()
    $Client.Dispose()
}


function Send-NetworkData {
    [CmdletBinding()]
    param (
        [Alias("Computer")]
        [Parameter(Mandatory)]
        [string]
        $ComputerName,

        [Alias("Port")]
        [Parameter(Mandatory)]
        [ValidateRange(1, 65535)]
        [Int16]
        $TCPPort,

        [Parameter(ValueFromPipeline)]
        [string[]]
        $Data,

        [System.Text.Encoding]
        $Encoding = [System.Text.Encoding]::ASCII,

        [TimeSpan]
        $Timeout = [System.Threading.Timeout]::InfiniteTimeSpan,

        [Switch]$NoReply
    ) 
    begin {
        # establish the connection and a stream writer
        $Client = New-Object -TypeName System.Net.Sockets.TcpClient
        $Client.Connect($ComputerName, $TCPPort)
        $Stream = $Client.GetStream()
        $Writer = New-Object -Type System.IO.StreamWriter -ArgumentList $Stream, $Encoding, $Client.SendBufferSize, $true
    }
    process {
        # send all the input data
        foreach ($Line in $Data) {
            $Writer.WriteLine($Line)
        }
    }
    end {
        # flush and close the connection send
        $Writer.Flush()
        #
        sleep 1

        # read the response
        $Stream.ReadTimeout = [System.Threading.Timeout]::Infinite
        if ($Timeout -ne [System.Threading.Timeout]::InfiniteTimeSpan) {
            $Stream.ReadTimeout = $Timeout.TotalMilliseconds
        }

        $Result = ''
        $Buffer = New-Object -TypeName System.Byte[] -ArgumentList $Client.ReceiveBufferSize
        do {
            try {
                $ByteCount = $Stream.Read($Buffer, 0, $Buffer.Length)
            } catch [System.IO.IOException] {
                $ByteCount = 0
            }
            if ($ByteCount -gt 0) {
                $Result += $Encoding.GetString($Buffer, 0, $ByteCount)
            }
        } while ($Stream.DataAvailable) 

        Write-Output $Result
        
        # cleanup
        $Writer.Dispose()
        $Client.Client.Shutdown('Send')

        $Stream.Dispose()
        $Client.Dispose()
    }
}

function Send-NetworkDataNoReply {
    [CmdletBinding()]
    param (
        [Alias("Computer")][Parameter(Mandatory)][string]$ComputerName,
        [Parameter(Mandatory)]
        [Alias("Port")][ValidateRange(1, 65535)][Int16]$TCPPort,
        [Parameter(Mandatory)][string[]]$Data,
        [System.Text.Encoding]$Encoding = [System.Text.Encoding]::ASCII
    )
    begin {
        # establish the connection and a stream writer
        $Client = New-Object -TypeName System.Net.Sockets.TcpClient
        $Client.Connect($ComputerName, $TCPPort)
        $Stream = $Client.GetStream()
        $Writer = New-Object -Type System.IO.StreamWriter -ArgumentList $Stream, $Encoding, $Client.SendBufferSize, $true
    }
    process {
        # send all the input data
        foreach ($Line in $Data) {
            $Writer.WriteLine($Line)
        }
    }
    end {
        # flush and close the connection send
        $Writer.Flush()
        #
        sleep 1
        # cleanup
        $Writer.Dispose()
        $Client.Client.Shutdown('Send')

        $Stream.Dispose()
        $Client.Dispose()
    }
}

