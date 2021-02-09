Function Show-RadioList
{

	[CmdletBinding()]
	Param (
		[parameter(Mandatory = $true, ValueFromPipeline = $true)]
		[object]$list,
		[string]$Title = "Radiobox List",
		[string]$Header = "Please select an item :"
	)

    Begin 
    {
        Function Add-RadioboxItem
        {
	        Param (
		        [object]$item,
		        [object]$parent
	        )
			$item = $item.split("|")
            $name = $item[0]

	        $RadioboxItem = New-Object System.Windows.Controls.RadioButton
	        $RadioboxItem.Margin = "5,0"
	        $RadioboxItem.Content = $name
            if($item[1] -eq 1) {$RadioboxItem.IsChecked = $true; [void]$script:checked.Add($name) }
            $RadioboxItem.Add_Checked({$script:checked.Add($This.Content)})
            $RadioboxItem.Add_UnChecked({$script:checked.Remove($This.Content)})
				
	        [void]$parent.Children.Add($RadioboxItem)
			
        }

    }

    Process 
    {
    #Build the GUI
    [xml]$xaml = @"
    <Window 
		xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' 
		xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' 
        Title='$Title' SizeToContent='WidthAndHeight' Background='#F0F0F0'
		WindowStartupLocation='CenterScreen' MaxHeight='800' MaxWidth='550' MinWidth='350'>
    <Grid>
    <Label x:Name='label' Content='$header' HorizontalAlignment='Left' Margin='10,4,10,0' VerticalAlignment='Top'/>
    <StackPanel Orientation='Vertical' VerticalAlignment='Top' Margin='10,30,10,10'>
        <Border BorderBrush='Gray' BorderThickness = '1' Background='White'>
        <DockPanel
        HorizontalAlignment="Stretch" 
        VerticalAlignment="Stretch" 
        MaxHeight="450">
        <ScrollViewer HorizontalScrollBarVisibility="Auto">
        <StackPanel Name='ParentStack' Background='#FFFFFF' Margin='3,3,3,3'></StackPanel>
        </ScrollViewer>
        </DockPanel>
        </Border>
        <StackPanel HorizontalAlignment='Right' Orientation='Horizontal' VerticalAlignment='Bottom' Margin='0,10,10,0'> 
            <Button Name='cancelbutton' Content='Cancel' Margin='0,0,0,0' Width='75'/>  
		    <Label Width='10'/>            
            <Button Name='okbutton' Content='OK'  Margin='0,0,0,0' Width='75'/>
        </StackPanel>    
    </StackPanel>
    </Grid>
</Window>
"@

    $reader=(New-Object System.Xml.XmlNodeReader $xaml)

    #Connect to Controls
    $window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))

    $xaml.SelectNodes("//*[@Name]") | ForEach-Object { Set-Variable -Name ($_.Name) -Value $window.FindName($_.Name) -Scope Script }

    $script:checked = [System.Collections.ArrayList]@()

    $stack = $window.FindName("ParentStack")

    foreach ($item in ($list | Sort-Object))
    {
	    Add-RadioboxItem -item $item -Parent $stack
    }

    #Events
    $okbutton.Add_Click({
		    $window.Close()
		    $script:okay = $true
	    })
		
    $cancelbutton.Add_Click({
		    $script:checked = $null
		    $window.Close()
            break;
	    })


    $Window.Showdialog() | Out-Null
    }

    End 
    {
        if ($script:checked.length -gt 0 -and $script:okay -eq $true)
        {
	        return $script:checked
        }
    }
}
