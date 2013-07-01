class MainScreen < ProMotion::SectionedTableScreen
  title "2013 BA Styles"
  searchable :placeholder => "Search Styles"

  def will_appear
    @view_set_up ||= begin
      set_attributes self.view, { backgroundColor: UIColor.whiteColor }

      unless Device.ipad?
        set_nav_bar_right_button UIImage.imageNamed("info.png"), action: :open_about_screen
      end

      backBarButtonItem = UIBarButtonItem.alloc.initWithTitle("Back", style:UIBarButtonItemStyleBordered, target:nil, action:nil)
      self.navigationItem.backBarButtonItem = backBarButtonItem

      @reload_observer = App.notification_center.observe "ReloadNotification" do |notification|
        @table_setup = nil
        update_table_data
      end

      # Check to see if we should go directly into a style when the app is already loaded.
      @style_observer ||= App.notification_center.observe "GoDirectlyToStyle" do |notification|
        App.delegate.jump_to_style = notification.object[:object]
      end

      read_data
    end
  end

  def on_appear
    self.navigationController.setToolbarHidden(true, animated:true) unless searching?
  end

  def table_data
    return [] if @styles.nil?
    @table_setup ||= begin
      s = []
      s << judging_section_links if BeerJudge.is_installed?
      s << judging_section_preview if shows_beer_judging_section?
      # s << {
      #   title: "Introductions",
      #   cells: [
      #     intro_cell("Beer Introduction"),
      #     intro_cell("Mead Introduction"),
      #     intro_cell("Cider Introduction")
      #   ]
      # }

      @styles.each do |section|
        s << {
          title: section[:name],
          cells: build_subcategories(section)
        }
      end
      s
    end
  end

  def intro_cell(name)
    {
      title: name,
      searchable: false,
      cell_identifier: "IntroductionCell",
      action: :open_intro_screen,
      arguments: {:file => "#{name}.html", :title => name}
    }
  end

  def judging_section_links
    # Show the judging Tools
    {
      title: "Judging Tools",
      cells: judging_cells
    }
  end

  def judging_section_preview
    # Show the intro screen
    {
      title: "Judging Tools",
      cells: [{
        title: "Check Out the App!",
        cell_identifier: "JudgingCell",
        searchable: false,
        action: :open_judging_info_screen,
        image: {
          image:"judge.png",
          radius: 8
        }
      }]
    }
  end

  def shows_beer_judging_section?
    return true if BeerJudge.is_installed?
    App::Persistence['hide_judging_tools'].nil? ||  App::Persistence['hide_judging_tools'] == false
  end

  def judging_cells
    c = []
    %w(Flavor\ Wheel SRM\ Spectrum SRM\ Analyzer).each do |tool|
      downcased_tool = tool.downcase.tr(" ", "_")
      c << {
        title: tool,
        searchable: false,
        cell_identifier: "JudgingCell",
        action: :open_judging_tool,
        arguments: {url: downcased_tool},
        image: "judge_#{downcased_tool}.png"
      }
    end
    c
  end

  def build_subcategories(section)
    c = []
    section[:substyles].each do |subcat|
      c << {
        title: subcat.title,
        search_text: subcat.search_text,
        cell_identifier: "SubcategoryCell",
        action: :open_style,
        arguments: {:style => subcat}
      }
    end
    c
  end

  def open_style(args={})
    if Device.ipad?
      open DetailScreen.new(args), nav_bar:true, in_detail: true
    else
      open DetailScreen.new(args)
    end
  end

  def open_about_screen(args={})
    open_modal AboutScreen.new(external_links: true),
      nav_bar: true,
      presentation_style: UIModalPresentationFormSheet
  end

  def open_intro_screen(args={})
    if Device.ipad?
      open IntroScreen.new(args), nav_bar:true, in_detail: true
    else
      open IntroScreen.new(args)
    end
  end

  def open_judging_info_screen
    open_modal JudgingInfoScreen.new, nav_bar: true, presentation_style: UIModalPresentationFormSheet
  end

  def open_judging_tool(args={})
    BeerJudge.open(args[:url])
  end

  private
  def read_data
    @done_read_data ||= begin

      @styles = []
      db = SQLite3::Database.new(File.join(App.resources_path, "styles.sqlite"))
      db.execute("SELECT * FROM category ORDER BY id") do |row|
        substyles = []
        db.execute("SELECT * FROM subcategory WHERE category = #{row[:id]} ORDER BY id") do |row2|
          substyles << Style.new(row2)
        end
        row[:substyles] = substyles
        @styles << row
      end

      @table_setup = nil
      update_table_data
    end
  end

end