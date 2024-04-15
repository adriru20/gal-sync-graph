function Sync-GALContacts {
    [cmdletbinding()]
    param (
        [parameter(Mandatory)][string]$Mailbox,
        [parameter(Mandatory)][string]$ContactFolderName,
        [parameter(Mandatory)][array]$ContactList
    )

    Write-Host "`nUsuario $($Mailbox)" -ForegroundColor green
    Write-LogEvent -Level Info -Message "Iniciando sincronizacion para $($Mailbox)"

    # Get/create contact folder
    try {
        $contactFolder = Get-ContactFolder -Mailbox $Mailbox -ContactFolderName $ContactFolderName
        if ($contactFolder)
        {
            Write-LogEvent -Level Info -Message "Carpeta encontrada $($ContactFolderName) para $($Mailbox)"

        }
        else {
            try {
                $contactFolder = New-ContactFolder -Mailbox $Mailbox -ContactFolderName $ContactFolderName
                Write-LogEvent -Level Info -Message "Carpeta creada $($ContactFolderName) para $($Mailbox)"
            }
            catch { throw "Algo salio mal al crear la carpeta de contactos" }
        }
        if (-not $contactFolder) { throw "No se encontro ninguna carpeta de contactos o no se pudo crear una" }
    }
    catch {
        throw "Algo salio mal al obtener la carpeta de contactos de $($Mailbox)"
    }

    Write-LogEvent -Level Info -Message "Obteniendo contactos en la carpeta"

    # get contacts in that folder
    try {
        $contactsInFolder = Get-FolderContact -ContactFolder $contactFolder
    }
    catch {
        throw "No se pudo crear la carpeta de contactos $($ContactFolderName) en $($Mailbox)"
    }

    Write-LogEvent -Level Info -Message "Eliminando contactos que ya no existen de la carpeta"

    if ($contactsInFolder) {
        $removeContacts = $contactsInFolder | Where-Object { $_.displayName -notin $ContactList.displayName }
        # Remove contacts that have duplicate displayNames. This is the only way to correctly sync
        # contacts when using displayName as the "primary key"

        # TODO: ERROR AL DESCOMENTAR LA SIGUIENTE LINEA
        # $removeContacts += $contactsInFolder | Group-Object displayName | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Group }

        if ($removeContacts) {
            foreach ($contact in $removeContacts) {
                try {
                    Remove-FolderContact -Contact $contact -ContactFolder $contactFolder | Out-Null
                    Write-LogEvent -Level Info -Message "Contacto eliminado $($contact.displayName)"
                }
                catch {
                    Write-LogEvent -Level Error -Message "No se pudo eliminar el contacto $($contact.displayName)"
                }
            }
        }

        Write-LogEvent -Level Info -Message "Contactos eliminados"

        # Get contacts in that folder again (after we've possibly removed some of them)
        try {
            $contactsInFolder = Get-FolderContact -ContactFolder $contactFolder
        }
        catch {
            throw "No se pudo crear la carpeta de contactos $($ContactFolderName) en $($Mailbox)"
        }

        function Check-Contact {
            [CmdletBinding()]
            param (
                $ContactInFolder,
                $Contact
            )
            # loop over the properties in each contact
            foreach ($property in $ContactInFolder.PSObject.Properties) {
                $name = $property.name
                $contactListValue = $contact.$name
                $folderContactValue = $property.value

                if ($name -ne "id") {
                    if ($folderContactValue -is [array] -and $name -eq "emailAddresses") {
                        $folderContactHashes = @()
                        $folderContactValue | ForEach-Object {
                            $folderContactHashes += @{
                                name = $_.name
                                address = $_.address
                            }
                        }
                        $difference = Compare-Object $contactListValue $folderContactHashes
                        if ($null -ne $difference) {
                            Write-Verbose "$name es diferente"
                            $returnContact = $contact
                        }
                    }
                    elseif ($contactListValue -ne $folderContactValue) {
                        if (-not [string]::IsNullOrEmpty($contactListValue) -and -not [string]::IsNullOrEmpty($folderContactValue)) {
                            Write-Verbose "$name es diferente"
                            $returnContact = $contact
                        }
                    }
                }
            }
            if ($null -ne $returnContact) {
                $returnContact | Add-Member -MemberType NoteProperty -Name "id" -Value $ContactInFolder.id -Force
                return $returnContact
            }
            else {
                return $null
            }
        }

        # foreach loop over the contactlist to compare to contacts in folder
        $updateContacts = @()
        foreach ($contact in $ContactList) {
            # find matching contact
            $folderContact = $contactsInFolder | Where-Object { $_.displayName -eq $contact.displayname }
            if ($folderContact) {
                Write-Verbose "Checking contact $($contact.displayname)"
                $checkedContact = Check-Contact -ContactInFolder $folderContact -Contact $contact
                if ($checkedContact) { $updateContacts += $checkedContact }
            }
        }

        if ($updateContacts) {
            foreach ($contact in $updateContacts) {
                try {
                    Update-FolderContact -Contact $contact -ContactFolder $contactFolder | Out-Null
                    Write-LogEvent -Level Info -Message "Contacto actualizado $($contact.displayName)"
                }
                catch {
                    Write-LogEvent -Level Error -Message "No se pudo actualizar el contacto $($updatedContact.displayName)"
                }
            }
        }
        # Get contacts in that folder again (after we've possibly modified some of them)
        try {
            $contactsInFolder = Get-FolderContact -ContactFolder $contactFolder
        }
        catch {
            throw "No se pudo crear la carpeta de contactos $($ContactFolderName) en $($Mailbox)"
        }
    }

    Write-LogEvent -Level Info -Message "Comparando la lista de contactos"

    # compare lists of new contacts vs old.
    if (-not $contactsInFolder) {
        $newContacts = $ContactList
    }
    else {
        $newContacts = $ContactList | Where-Object { $_.displayName -notin $contactsInFolder.displayName }
    }

    if ($newContacts) {
        foreach ($contact in $newContacts) {
            try {
                New-FolderContact -Contact $contact -ContactFolder $contactFolder | Out-Null
                Write-LogEvent -Level Info -Message "Contacto creado $($contact.displayName)"
            }
            catch {
                Write-LogEvent -Level Error -Message "No se pudo crear contacto $($contact.displayName)"
            }
        }
    }
    if (-not $newContacts -and -not $updateContacts -and -not $removeContacts) {
        Write-LogEvent -Level Info -Message "No hay contactos disponibles para sincronizar"
    }
}