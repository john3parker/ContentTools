class ButtonLink extends ContentTools.Tools.Link

    # Insert/Update a ButtonLink.

    ContentTools.ToolShelf.stow(@, 'buttonlink')

    @label = 'Button link'
    @icon = 'buttonlink'
    @tagName = 'a'

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
        else if element.isFixed() and element.tagName() is 'a'
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
        if element.type() is 'Image'
            return element.a
        else if element.isFixed() and element.tagName() is 'a'
            return true
        else
            return super(element, selection)

    @apply: (element, selection, callback) ->
        # Dispatch `apply` event
        toolDetail = {
            'tool': this,
            'element': element,
            'selection': selection
            }
        if not @dispatchEditorEvent('tool-apply', toolDetail)
            return

        applied = false

        # Prepare text elements for adding a link
        if element.type() is 'Image'
            # Images
            rect = element.domElement().getBoundingClientRect()

        else if element.isFixed() and element.tagName() is 'a'
            # Fixtures
            rect = element.domElement().getBoundingClientRect()

        else
            # If the selection is collapsed then we need to select the entire
            # entire link.
            if selection.isCollapsed()

                # Find the bounds of the link
                characters = element.content.characters
                starts = selection.get(0)[0]
                ends = starts

                while starts > 0 and characters[starts - 1].hasTags('a')
                    starts -= 1

                while ends < characters.length and characters[ends].hasTags('a')
                    ends += 1

                # Select the link in full
                selection = new ContentSelect.Range(starts, ends)
                selection.select(element.domElement())

            # Text elements
            element.storeState()

            # Add a fake selection wrapper to the selected text so that it
            # appears to be selected when the focus is lost by the element.
            selectTag = new HTMLString.Tag('span', {'class': 'ct--pseudo-select'})
            [from, to] = selection.get()
            element.content = element.content.format(from, to, selectTag)
            element.updateInnerHTML()

            # Measure a rectangle of the content selected so we can position the
            # dialog centrally.
            domElement = element.domElement()
            measureSpan = domElement.getElementsByClassName('ct--pseudo-select')
            rect = measureSpan[0].getBoundingClientRect()

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
                element.content = element.content.unformat(from, to, selectTag)
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
        console.log('class=', @getAttr('class', element, selection))
        dialog = new ButtonLinkDialog(
            @getAttr('href', element, selection),
            @getAttr('target', element, selection)
            @getAttr('class', element, selection)
            )

        dialog.addEventListener 'save', (ev) ->
            detail = ev.detail()

            applied = true
            console.log('saving!')

            # Add the link
            if element.type() is 'Image'

                # Images
                #
                # Note: When we add/remove links any alignment class needs to be
                # moved to either the link (on adding a link) or the image (on
                # removing a link). Alignment classes are mutually exclusive.
                alignmentClassNames = [
                    'align-center',
                    'align-left',
                    'align-right'
                    ]

                if detail.href
                    element.a = {href: detail.href}

                    if detail.target
                        element.a.target = detail.target

                    for className in alignmentClassNames
                        if element.hasCSSClass(className)
                            element.removeCSSClass(className)
                            element.a['class'] = className
                            break

                else
                    linkClasses = []
                    if element.a['class']
                        linkClasses = element.a['class'].split(' ')
                    for className in alignmentClassNames
                        if linkClasses.indexOf(className) > -1
                            element.addCSSClass(className)
                            break
                    element.a = null

                element.unmount()
                element.mount()

            else if element.isFixed() and element.tagName() is 'a'
                # Fixtures
                element.attr('href', detail.href)

            else
                # Text elements

                # Attempt to find any existing tag
                firstATag = null
                for i in [from...to]
                    for tag in element.content.characters[i].tags()
                        if tag.name() == 'a'
                            firstATag = tag
                            break

                    if firstATag
                        break

                # Clear any existing link
                element.content = element.content.unformat(from, to, 'a')

                # If specified add the new link
                if detail.href

                    if firstATag
                        a = firstATag.copy()
                    else
                        a = new HTMLString.Tag('a')

                    a.attr('href', detail.href)
                    if detail.target
                        a.attr('target', detail.target)
                    else
                        a.removeAttr('target')

                    console.log('building Anchor', a, detail)
                    if (detail.style)
                        a.attr('class', 'btn ' + detail.style)
                    else
                        a.attr('class', '')
                    a.attr('style', 'font-size: inherit;')

                    element.content = element.content.format(from, to, a)
                    element.content.optimize()

                element.updateInnerHTML()
                #a.addCSSClass('btn')
                #a.addCSSClass('btn-primary')

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



class ButtonLinkDialog extends ContentTools.DialogUI

    # A dialog to support inserting/update a buttonLink

    constructor: (@buttonLink, @buttonTarget, @buttonClasses)->
        console.log('dialog link=', @buttonLink, @buttonTarget, @buttonClasses)
        if @buttonLink
            super('Update button link')
        else
            super('Insert button link')

    # Methods

    mount: () ->
        # Mount the widget
        super()

        # Build the initial configuration of the dialog
        cfg = {url: '', style: '', target: @buttonTarget}
        if @buttonLink
            cfg.url = @buttonLink

        if @buttonClasses
            for className in @buttonClasses.split(' ')
                console.log('className=', className)
                cfg[className] = true
            
            #console.log(@buttonClasses.split(' ')[1])
            #if (@buttonClasses.split(' ')[1].length > 1)
            #    cfg.style = @buttonClasses.split('-')[1]
            #    cfg[@buttonClasses.split('-')[1]] = true

        # Update dialog class
        ContentEdit.addCSSClass(@_domElement, 'ct-table-dialog')

        # Update view class
        ContentEdit.addCSSClass(@_domView, 'ct-table-dialog__view')

        # Add sections

        # URL
        @_domBodySection = @constructor.createDiv([
            'ct-section',
            'ct-section--applied',
            'ct-section--contains-input'
            ])
        @_domView.appendChild(@_domBodySection)

        domBodyLabel = @constructor.createDiv(['ct-section__label'])
        domBodyLabel.textContent = ContentEdit._('URL')
        domBodyLabel.setAttribute('style', 'width: 50px;')
        @_domBodySection.appendChild(domBodyLabel)

        @_domBodyInput = document.createElement('input')
        @_domBodyInput.setAttribute('class', 'form-control')
        @_domBodyInput.setAttribute('maxlength', '255')
        @_domBodyInput.setAttribute('name', 'linkUrl')
        @_domBodyInput.setAttribute('type', 'text')
        @_domBodyInput.setAttribute('value', cfg.url)
        @_domBodyInput.setAttribute('style', 'width: 89%; height: 46px;')
        @_domBodyInput.setAttribute('placeholder', 'Enter a link...')
        @_domBodySection.appendChild(@_domBodyInput)

        # HREF Target
        # Add a button class section e.g btn-primary
        targetCSSClasses = ['ct-section']
        if cfg.target
            targetCSSClasses.push('ct-section--applied')
        else
            console.log('targetis set to =', cfg.target, cfg)
        @_domTargetSection = @constructor.createDiv(targetCSSClasses)
        @_domView.appendChild(@_domTargetSection)

        targetLabel = @constructor.createDiv(['ct-section__label'])
        targetLabel.textContent = ContentEdit._('Open in new window')
        @_domTargetSection.appendChild(targetLabel)

        @_domTargetSwitch = @constructor.createDiv(['ct-section__switch'])
        @_domTargetSection.appendChild(@_domTargetSwitch)

        # Add event listener      
        @_domTargetSection.addEventListener 'click', this.toggleSection

        # SELECT for CLASSES
        @_domClassSection = @constructor.createDiv([
            'ct-section',
            'ct-section--applied',
            'ct-section--contains-input'
            ])
        @_domView.appendChild(@_domClassSection)

        domClassSelectLabel = @constructor.createDiv(['ct-section__label'])
        domClassSelectLabel.textContent = ContentEdit._('Style')
        domClassSelectLabel.setAttribute('style', 'width: 50px;')
        @_domClassSection.appendChild(domClassSelectLabel)

        @_domClassSelect = document.createElement('select')
        @_domClassSelect.setAttribute('class', 'form-select')
        @_domClassSelect.setAttribute('maxlength', '255')
        @_domClassSelect.setAttribute('name', 'buttonStyle')
        @_domClassSelect.setAttribute('style', 'width: 89%; height: 46px;')
        @_domClassSelect.setAttribute('placeholder', 'Select a button style...')
        @_domClassSection.appendChild(@_domClassSelect)


        self = this
        classStyles = [
            {name: 'No button style', style:''},
            {name: 'Button primary', style:'btn-primary'},
            {name: 'Button secondary', style:'btn-secondary'},
            {name: 'Button success', style:'btn-success'},
            {name: 'Button danger', style:'btn-danger'},
            {name: 'Button warning', style:'btn-warning'},
            {name: 'Button info', style:'btn-info'},
            {name: 'Button light', style:'btn-light'},
            {name: 'Button dark', style:'btn-dark'}
        ]

        for style in classStyles
            domStyleOption = document.createElement('option')
            domStyleOption.setAttribute('value', style.style)
            domStyleOption.textContent = ContentEdit._(style.name)
            if (cfg[style.style])
                domStyleOption.setAttribute('selected', '')
            self._domClassSelect.append(domStyleOption)

        # SELECT FOR BUTTON SIZE
        @_domButtonSizeSection = @constructor.createDiv([
            'ct-section',
            'ct-section--applied',
            'ct-section--contains-input'
            ])
        @_domView.appendChild(@_domButtonSizeSection)

        domButtonSizeLabel = @constructor.createDiv(['ct-section__label'])
        domButtonSizeLabel.textContent = ContentEdit._('Size')
        domButtonSizeLabel.setAttribute('style', 'width: 50px;')
        @_domButtonSizeSection.appendChild(domButtonSizeLabel)

        @_domButtonSizeSelect = document.createElement('select')
        @_domButtonSizeSelect.setAttribute('class', 'form-select')
        @_domButtonSizeSelect.setAttribute('maxlength', '255')
        @_domButtonSizeSelect.setAttribute('name', 'buttonSize')
        @_domButtonSizeSelect.setAttribute('style', 'width: 89%; height: 46px;')
        @_domButtonSizeSelect.setAttribute('placeholder', 'Select a button size...')
        @_domButtonSizeSection.appendChild(@_domButtonSizeSelect)

        buttonSizes = [
            {name: 'No sizing (default)', style:''},
            {name: 'Small button', style:'btn-sm'},
            {name: 'Large button', style:'btn-lg'},
            {name: 'XLarge button', style:'p-5'},
        ]

        for size in buttonSizes
            domStyleOption = document.createElement('option')
            domStyleOption.setAttribute('value', size.style)
            domStyleOption.textContent = ContentEdit._(size.name)
            if (cfg[size.style])
                domStyleOption.setAttribute('selected', '')
            self._domButtonSizeSelect.append(domStyleOption)

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
            href: @_domBodyInput.value,
            style: @_domClassSelect.value + ' ' + @_domButtonSizeSelect.value,
        }

        # Set the "target" configuration selected by the user
        if @_domTargetSection.getAttribute('class').indexOf('ct-section--applied') > -1
            detail.target = '_blank'
        
        @dispatchEvent(@createEvent('save', detail))

    unmount: () ->
        # Unmount the component from the DOM
        super()

        @_domBodyInput = null
        @_domBodySection = null
        @_domApply = null

        @_domClassSelect = null
        @_domButtonSizeSelect = null

    # Private methods

    _addDOMEventListeners: () ->
        # Add event listeners for the widget
        super()

        # Focus on the columns input if the section is clicked
        @_domBodySection.addEventListener 'click', (ev) =>
            @_domBodyInput.focus()

        # Apply button
        @_domApply.addEventListener 'click', (ev) =>
            ev.preventDefault()

            # Check the button isn't muted, if it is then the ButtonLink
            # configuration isn't valid.
            cssClass = @_domApply.getAttribute('class')
            if cssClass.indexOf('ct-control--muted') == -1
                @save()

