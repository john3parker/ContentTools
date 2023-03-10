class StyleTool extends ContentTools.Tools.Link

    # Insert/Update a ButtonLink.

    ContentTools.ToolShelf.stow(@, 'styletool')

    @label = 'Style Tool'
    @icon = 'styletool'
    @tagName = ''

    # Class methods
    @getAttr: (attrName, element, selection) ->
        # Get an attribute for the element and selection

        # Images
        if element.type() is 'Image'
            if element.a
                return element.a[attrName]

        # Fixtures
        else if element.isFixed() and element.tagName() is 'a'
            return element.attr(attrName)

        # Text
        else
            # Find the first character in the selected text that has an `a` tag
            # and return the named attributes value.
            [from, to] = selection.get()
            selectedContent = element.content.slice(from, to)
            for c in selectedContent.characters
                if not c.hasTags('a')
                    continue

                for tag in c.tags()
                    if tag.name() == 'a'
                        return tag.attr(attrName)

        return ''
    
    @canApply: (element, selection) ->

        # Return true if the tool can be applied to the current
        # element/selection.
        
        if element.type() is 'Image'
            return true
        else if element.type() is 'Text'
            return true
        else if element.isFixed() and element.tagName() is 'a'
            return true
        else if element.isFixed() and element.tagName() is 'h1'
            return true
        else
            # Must support content
            unless element.content
                return false

            # A selection must exist
            if not selection
                return false

            # If the selection is collapsed then it must be within an existing
            # link.
            if selection.isCollapsed()
                character = element.content.characters[selection.get()[0]]
                if not character or not character.hasTags('a')
                    return false

            return true

    @isApplied: (element, selection) ->
        # Return true if the tool is currently applied to the current
        # element/selection.
        if element.content is undefined or not element.content.length()
            return false

        if selection
            [from, to] = selection.get()
            if from == to
                to += 1

            return element.content.slice(from, to).hasTags(@tagName, true)
        return false

    @apply: (element, selection, callback) ->

        # console.log('apply', element)
        # Dispatch `apply` event
        toolDetail = {
            'tool': this,
            'element': element,
            'selection': selection
            }
        if not @dispatchEditorEvent('tool-apply', toolDetail)
            return

        applied = false
        
        # Set-up the dialog
        app = ContentTools.EditorApp.get()

        # Modal
        modal = new ContentTools.ModalUI(transparent=true, allowScrolling=true)

        # When the modal is clicked on the dialog should close
        modal.addEventListener 'click', () ->
            @unmount()
            dialog.hide()

            if element.content
                # Remove the fake selection from the element
                #element.content = element.content.unformat(from, to, selectTag)
                element.updateInnerHTML()

                # Restore the selection
                element.restoreState()

            callback(applied)

            # Dispatch `applied` event
            if applied
                ContentTools.Tools.Link.dispatchEditorEvent(
                    'tool-applied',
                    toolDetail
                    )

        # Dialog
        # console.log('class=', element.attr('class'))
        # console.log('style=', element.attr('style'))

        dialog = new StyleToolDialog(
            element.attr('class')
            element.attr('style')
            )

        dialog.addEventListener 'save', (ev) ->
            detail = ev.detail()

            applied = true
            # console.log('saving! detail=', ev.detail(), element)

            classes = element.attr('class')
            if classes
                for className in classes.split(' ') 
                    element.removeCSSClass(className)
            
            if (ev.detail().textColor)
                element.addCSSClass(ev.detail().textColor)
            if (ev.detail().textBackgroundColor)
                element.addCSSClass(ev.detail().textBackgroundColor)

            style = ''
            if (ev.detail().marginTop)
                style += 'margin-top:' + ev.detail().marginTop + ';'
            if (ev.detail().marginBottom)
                style += 'margin-bottom:' + ev.detail().marginBottom + ';'
            if (ev.detail().marginLeft)
                style += 'margin-left:' + ev.detail().marginLeft + ';'
            if (ev.detail().marginRight)
                style += 'margin-right:' + ev.detail().marginRight + ';'

            if (ev.detail().paddingTop)
                style += 'padding-top:' + ev.detail().paddingTop + ';'
            if (ev.detail().paddingBottom)
                style += 'padding-bottom:' + ev.detail().paddingBottom + ';'
            if (ev.detail().paddingLeft)
                style += 'padding-left:' + ev.detail().paddingLeft + ';'
            if (ev.detail().paddingRight)
                style += 'padding-right:' + ev.detail().paddingRight + ';'

            if (style)
                element.attr('style', style)

            # Make sure the element is marked as tainted
            element.taint()

            # Close the modal and dialog
            modal.dispatchEvent(modal.createEvent('click'))

        # Support cancelling the dialog
        dialog.addEventListener 'cancel', () =>

            modal.hide()
            dialog.hide()

            if element.restoreState
                element.restoreState()

            callback(false)
        
        app.attach(modal)
        app.attach(dialog)
        modal.show()
        dialog.show()

    # Private class methods



class StyleToolDialog extends ContentTools.DialogUI

    # A dialog to support inserting/update a buttonLink

    constructor: (@classes, @styles)->
        # console.log('StyleToolDialog', @classes, @styles)
        super('Styles')

    # Methods

    mount: () ->
        # Mount the widget
        super()

        # Build the initial configuration of the dialog
        cfg = {}

        if @classes
            for className in @classes.split(' ')
                # console.log('className=', className)
                cfg[className] = true

        if @styles
            @styles = @styles.replace(/\n/, "").replace(/\r/, "").replace(/\t/, "").trim()
            
            for style in @styles.split(';')
                # console.log('style=', style)
                styleParts = style.split(':')
                cfg[styleParts[0]] = styleParts[1]

        # console.log('cfg', cfg)
        # Update dialog class
        ContentEdit.addCSSClass(@_domElement, 'ct-table-dialog')

        # Update view class
        ContentEdit.addCSSClass(@_domView, 'ct-table-dialog__view')

        # Add sections

        # SELECT for CLASSES
        @_domTextColorSection = @constructor.createDiv([
            'ct-section',
            'ct-section--applied',
            'ct-section--contains-input'
            ])
        @_domView.appendChild(@_domTextColorSection)

        domTextColorLabel = @constructor.createDiv(['ct-section__label'])
        domTextColorLabel.textContent = ContentEdit._('Text color')
        domTextColorLabel.setAttribute('style', 'width: 50%;')
        @_domTextColorSection.appendChild(domTextColorLabel)

        @_domTextColorSelect = document.createElement('select')
        @_domTextColorSelect.setAttribute('class', 'form-select')
        @_domTextColorSelect.setAttribute('style', 'width: 50%; height: 46px;')
        @_domTextColorSection.appendChild(@_domTextColorSelect)

        self = this
        textColorStyles = [
            {name: 'No text style', style:''},
            {name: 'Text primary', style:'text-primary'},
            {name: 'Text secondary', style:'text-secondary'},
            {name: 'Text success', style:'text-success'},
            {name: 'Text danger', style:'text-danger'},
            {name: 'Text warning', style:'text-warning'},
            {name: 'Text info', style:'text-info'},
            {name: 'Text light', style:'text-light'},
            {name: 'Text dark', style:'text-dark'}
        ]

        for textColor in textColorStyles
            domStyleOption = document.createElement('option')
            domStyleOption.setAttribute('value', textColor.style)
            domStyleOption.textContent = ContentEdit._(textColor.name)
            if (cfg[textColor.style])
                domStyleOption.setAttribute('selected', '')
            self._domTextColorSelect.append(domStyleOption)

        # SELECT FOR BUTTON SIZE
        @_domTextBackgroundColorSection = @constructor.createDiv([
            'ct-section',
            'ct-section--applied',
            'ct-section--contains-input'
            ])
        @_domView.appendChild(@_domTextBackgroundColorSection)

        domTextBackgroundColorLabel = @constructor.createDiv(['ct-section__label'])
        domTextBackgroundColorLabel.textContent = ContentEdit._('Text background color')
        domTextBackgroundColorLabel.setAttribute('style', 'width: 50%;')
        @_domTextBackgroundColorSection.appendChild(domTextBackgroundColorLabel)

        @_domTextBackgroundColorSelect = document.createElement('select')
        @_domTextBackgroundColorSelect.setAttribute('class', 'form-select')
        @_domTextBackgroundColorSelect.setAttribute('maxlength', '255')
        @_domTextBackgroundColorSelect.setAttribute('name', 'buttonSize')
        @_domTextBackgroundColorSelect.setAttribute('style', 'width: 50%; height: 46px;')
        @_domTextBackgroundColorSelect.setAttribute('placeholder', 'Select a button size...')
        @_domTextBackgroundColorSection.appendChild(@_domTextBackgroundColorSelect)

        textBackgroundColorStyles = [
            {name: 'No text background style', style:''},
            {name: 'Text Background primary', style:'text-bg-primary'},
            {name: 'Text Background secondary', style:'text-bg-secondary'},
            {name: 'Text Background success', style:'text-bg-success'},
            {name: 'Text Background danger', style:'text-bg-danger'},
            {name: 'Text Background warning', style:'text-bg-warning'},
            {name: 'Text Background info', style:'text-bg-info'},
            {name: 'Text Background light', style:'text-bg-light'},
            {name: 'Text Background dark', style:'text-bg-dark'}
        ]
        for textBackgroundColor in textBackgroundColorStyles
            domStyleOption = document.createElement('option')
            domStyleOption.setAttribute('value', textBackgroundColor.style)
            domStyleOption.textContent = ContentEdit._(textBackgroundColor.name)
            if (cfg[textBackgroundColor.style])
                domStyleOption.setAttribute('selected', '')
            self._domTextBackgroundColorSelect.append(domStyleOption)

        
        # MARGINS
        @_domMarginSection = @constructor.createDiv([
            'ct-section',
            'ct-section--applied',
            'ct-section--contains-input'
            'row'
            'mt-2'
            ])
        @_domPaddingSection = @constructor.createDiv([
            'ct-section',
            'ct-section--applied',
            'ct-section--contains-input'
            'row'
            'mt-2'
            ])
        @_domView.appendChild(@_domMarginSection)
        @_domView.appendChild(@_domPaddingSection)


        @_domMarginTopInput = @createInput('domMarginTopInput','Top margin', cfg['margin-top'])
        @_domMarginBottomInput = @createInput('domMarginBottomInput','Bottom margin', cfg['margin-bottom'])
        @_domMarginLeftInput = @createInput('domMarginLeftInput','Left margin', cfg['margin-left'])
        @_domMarginRightInput = @createInput('domMarginRightInput','Right margin', cfg['margin-right'])

        @_domPaddingTopInput = @createInput('domPaddingTopInput','Top padding', cfg['padding-top'])
        @_domPaddingBottomInput = @createInput('domPaddingBottomInput','Bottom padding', cfg['padding-bottom'])
        @_domPaddingLeftInput = @createInput('domPaddingLeftInput','Left padding', cfg['padding-left'])
        @_domPaddingRightInput = @createInput('domPaddingRightInput','Right padding', cfg['padding-right'])

        @_domMarginSection.appendChild(@_domMarginTopInput)
        @_domMarginSection.appendChild(@_domMarginBottomInput)
        @_domMarginSection.appendChild(@_domMarginLeftInput)
        @_domMarginSection.appendChild(@_domMarginRightInput)

        @_domPaddingSection.appendChild(@_domPaddingTopInput)
        @_domPaddingSection.appendChild(@_domPaddingBottomInput)
        @_domPaddingSection.appendChild(@_domPaddingLeftInput)
        @_domPaddingSection.appendChild(@_domPaddingRightInput)

        # Add controls
        domControlGroup = @constructor.createDiv(
            ['ct-control-group', 'ct-control-group--right'])
        @_domControls.appendChild(domControlGroup)

        # Apply button
        @_domApply = @constructor.createDiv([
            'ct-control',
            'ct-control--text',
            'ct-control--apply'
            ])
        @_domApply.textContent = 'Apply'
        domControlGroup.appendChild(@_domApply)

        # Add interaction handlers
        @_addDOMEventListeners()

    createInput: (name, label, defaultValue) ->
        domDiv = document.createElement('div')
        domDiv.setAttribute('class', 'form-floating col-3 pe-2')

        domInput = document.createElement('input')
        domInput.setAttribute('id', name)
        domInput.setAttribute('type', 'text')
        domInput.setAttribute('style', 'height: 46px;')
        domInput.setAttribute('class', 'form-control')
        domInput.setAttribute('placeholder', label)
        if (defaultValue)
            domInput.setAttribute('value', defaultValue)

        domMarginTopLabel = document.createElement('label')
        domMarginTopLabel.setAttribute('for', name)
        domMarginTopLabel.setAttribute('style', 'padding: 0;')
        domMarginTopLabel.textContent = ContentEdit._(label)

        domDiv.appendChild(domInput)
        domDiv.appendChild(domMarginTopLabel)
        
        return domDiv

    # Add support for the head and foot switches
    toggleSection: (ev) ->
        ev.preventDefault()

        # Toggle applied class
        if this.getAttribute('class').indexOf('ct-section--applied') > -1
            ContentEdit.removeCSSClass(this, 'ct-section--applied')
        else
            ContentEdit.addCSSClass(this, 'ct-section--applied')

    save: () ->
        # Save the ButtonLink. The event trigged by saving the ButtonLink includes a
        # dictionary with the ButtonLink configuration in:
        #

        # Set the configuration selected by the user
        detail = {
            textColor: @_domTextColorSelect.value,
            textBackgroundColor: @_domTextBackgroundColorSelect.value,

            marginTop: document.getElementById('domMarginTopInput').value,
            marginBottom: document.getElementById('domMarginBottomInput').value,
            marginLeft: document.getElementById('domMarginLeftInput').value,
            marginRight: document.getElementById('domMarginRightInput').value,

            paddingTop: document.getElementById('domPaddingTopInput').value,
            paddingBottom: document.getElementById('domPaddingBottomInput').value,
            paddingLeft: document.getElementById('domPaddingLeftInput').value,
            paddingRight: document.getElementById('domPaddingRightInput').value,
        }
        
        @dispatchEvent(@createEvent('save', detail))

    unmount: () ->
        # Unmount the component from the DOM
        super()

        @_domBodyInput = null
        @_domBodySection = null
        @_domApply = null

        @_domTextColorSelect = null
        @_domTextBackgroundColorSelect = null

    # Private methods

    _addDOMEventListeners: () ->
        # Add event listeners for the widget
        super()

        # Apply button
        @_domApply.addEventListener 'click', (ev) =>
            ev.preventDefault()

            # Check the button isn't muted, if it is then the ButtonLink
            # configuration isn't valid.
            cssClass = @_domApply.getAttribute('class')
            if cssClass.indexOf('ct-control--muted') == -1
                @save()

