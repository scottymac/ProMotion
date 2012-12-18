module ProMotion::MotionTable
  module SectionedTable
    # @param [Array] Array of table data
    # @returns [UITableView] delegated to self
    def createTableViewFromData(data)
      setTableViewData data
      return table_view
    end

    def updateTableViewData(data)
      setTableViewData data
      self.table_view.reloadData
    end

    def setTableViewData(data)
      @mt_table_view_groups = data
    end

    def numberOfSectionsInTableView(table_view)
      if @mt_filtered
        return @mt_filtered_data.length if @mt_filtered_data
      else
        return @mt_table_view_groups.length if @mt_table_view_groups
      end
      0
    end

    # Number of cells
    def tableView(table_view, numberOfRowsInSection:section)
      return section_at_index(section)[:cells].length if section_at_index(section) && section_at_index(section)[:cells]
      0
    end

    def tableView(table_view, titleForHeaderInSection:section)
      return section_at_index(section)[:title] if section_at_index(section) && section_at_index(section)[:title]
    end

    # Set table_data_index if you want the right hand index column (jumplist)
    def sectionIndexTitlesForTableView(table_view)
      if self.respond_to?(:table_data_index)
        self.table_data_index 
      end
    end

    def tableView(table_view, cellForRowAtIndexPath:indexPath)
      # Aah, magic happens here...

      data_cell = cell_at_section_and_index(indexPath.section, indexPath.row)
      return UITableViewCell.alloc.init unless data_cell
      data_cell[:cellStyle] ||= UITableViewCellStyleDefault
      data_cell[:cellIdentifier] ||= "Cell"
      cellIdentifier = data_cell[:cellIdentifier]
      data_cell[:cellClass] ||= PM::TableViewCell

      table_cell = table_view.dequeueReusableCellWithIdentifier(cellIdentifier)
      unless table_cell
        table_cell = data_cell[:cellClass].alloc.initWithStyle(data_cell[:cellStyle], reuseIdentifier:cellIdentifier)
        
        # Add optimizations here
        table_cell.layer.masksToBounds = true if data_cell[:masksToBounds]
        table_cell.backgroundColor = data_cell[:backgroundColor] if data_cell[:backgroundColor]
        table_cell.selectionStyle = data_cell[:selectionStyle] if data_cell[:selectionStyle]
        table_cell.autoresizingMask = UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleLeftMargin|UIViewAutoresizingFlexibleRightMargin
      end

      if data_cell[:cellClassAttributes]
        set_cell_attributes table_cell, data_cell[:cellClassAttributes]
      end
      
      if data_cell[:accessoryView]
        table_cell.accessoryView = data_cell[:accessoryView]
        table_cell.accessoryView.autoresizingMask = UIViewAutoresizingFlexibleWidth
      end

      if data_cell[:accessory] && data_cell[:accessory] == :switch
        switchView = UISwitch.alloc.initWithFrame(CGRectZero)
        switchView.addTarget(self, action: "accessoryToggledSwitch:", forControlEvents:UIControlEventValueChanged);
        switchView.on = true if data_cell[:accessoryDefault]
        table_cell.accessoryView = switchView
      end

      if data_cell[:subtitle]
        table_cell.detailTextLabel.text = data_cell[:subtitle]
        table_cell.detailTextLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth
      end

      table_cell.selectionStyle = UITableViewCellSelectionStyleNone if data_cell[:no_select]

      if data_cell[:remoteImage]
        if table_cell.imageView.respond_to?("setImageWithURL:placeholderImage:")
          url = data_cell[:remoteImage][:url]
          url = NSURL.URLWithString(url) unless url.is_a?(NSURL)
          placeholder = data_cell[:remoteImage][:placeholder]
          placeholder = UIImage.imageNamed(placeholder) if placeholder.is_a?(String)

          table_cell.image_size = data_cell[:remoteImage][:size] if data_cell[:remoteImage][:size] && table_cell.respond_to?("image_size=")
          table_cell.imageView.setImageWithURL(url, placeholderImage: placeholder)
          table_cell.imageView.layer.masksToBounds = true
          table_cell.imageView.layer.cornerRadius = data_cell[:remoteImage][:radius]
        else
          ProMotion::MotionTable::Console.log("ProMotion Warning: to use remoteImage with TableScreen you need to include the CocoaPod 'SDWebImage'.", withColor: MotionTable::Console::RED_COLOR)
        end
      elsif data_cell[:image]
        table_cell.imageView.layer.masksToBounds = true
        table_cell.imageView.image = data_cell[:image][:image]
        table_cell.imageView.layer.cornerRadius = data_cell[:image][:radius] if data_cell[:image][:radius]
      end

      if data_cell[:subViews]
        tag_number = 0
        data_cell[:subViews].each do |view|
          # Remove an existing view at that tag number
          tag_number += 1
          existing_view = table_cell.viewWithTag(tag_number)
          existing_view.removeFromSuperview if existing_view

          # Add the subview if it exists
          if view
            view.tag = tag_number
            table_cell.addSubview view
          end
        end
      end

      if data_cell[:details]
        table_cell.addSubview data_cell[:details][:image]
      end

      if data_cell[:styles] && data_cell[:styles][:textLabel] && data_cell[:styles][:textLabel][:frame]
        ui_label = false
        table_cell.contentView.subviews.each do |view|
          if view.is_a? UILabel
            ui_label = true
            view.text = data_cell[:styles][:textLabel][:text]
          end
        end

        unless ui_label == true
          label ||= UILabel.alloc.initWithFrame(CGRectZero)
          set_cell_attributes label, data_cell[:styles][:textLabel]
          table_cell.contentView.addSubview label
        end
        # hackery
        table_cell.textLabel.textColor = UIColor.clearColor
      else
        cell_title = data_cell[:title]
        cell_title ||= ""
        table_cell.textLabel.text = cell_title
      end

      return table_cell
    end

    def section_at_index(index)
      if @mt_filtered
        @mt_filtered_data.at(index)
      else
        @mt_table_view_groups.at(index)
      end
    end

    def cell_at_section_and_index(section, index)
      return section_at_index(section)[:cells].at(index) if section_at_index(section) && section_at_index(section)[:cells]
    end

    def tableView(table_view, didSelectRowAtIndexPath:indexPath)
      cell = cell_at_section_and_index(indexPath.section, indexPath.row)
      table_view.deselectRowAtIndexPath(indexPath, animated: true);
      cell[:arguments] ||= {}
      cell[:arguments][:cell] = cell if cell[:arguments].is_a?(Hash)
      trigger_action(cell[:action], cell[:arguments]) if cell[:action]
    end

    def accessoryToggledSwitch(switch)
      table_cell = switch.superview
      indexPath = table_cell.superview.indexPathForCell(table_cell)

      data_cell = cell_at_section_and_index(indexPath.section, indexPath.row)
      data_cell[:arguments] = {} unless data_cell[:arguments]
      data_cell[:arguments][:value] = switch.isOn if data_cell[:arguments].is_a? Hash
      
      trigger_action(data_cell[:accessoryAction], data_cell[:arguments]) if data_cell[:accessoryAction]

    end

    def trigger_action(action, arguments)
      if self.respond_to?(action)
        expected_arguments = self.method(action).arity
        if expected_arguments == 0
          self.send(action)
        elsif expected_arguments == 1 || expected_arguments == -1
          self.send(action, arguments)
        else
          Console.log("MotionTable warning: #{action} expects #{expected_arguments} arguments. Maximum number of required arguments for an action is 1.", withColor: MotionTable::Console::RED_COLOR)
        end
      else
        Console.log(self, actionNotImplemented: action)
      end
    end
  
    def set_cell_attributes(element, args = {})
      args.each do |k, v|
        if v.is_a? Hash
          v.each do
            sub_element = element.send("#{k}")
            set_cell_attributes(sub_element, v)
          end
        else
          element.send("#{k}=", v) if element.respond_to?("#{k}=")
        end
      end
      element
    end
  end
end