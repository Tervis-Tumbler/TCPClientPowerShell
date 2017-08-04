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
        $Timeout = [System.Threading.Timeout]::InfiniteTimeSpan
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

