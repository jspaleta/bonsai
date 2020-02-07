module ExtensionsHelper
  #
  # Returns a URL for the latest version of the given extension
  #
  # @param extension [Extension]
  #
  # @return [String] the URL
  #
  def latest_extension_version_url(extension)
    api_v1_extension_version_url(
      extension,
      extension.latest_extension_version,
      username: extension.owner_name)
  end

  #
  # Show the contingent extension name and version
  #
  # @param contingent [ExtensionDependency]
  #
  # @return [String] the link to the contingent extension
  #
  def contingent_link(dependency)
    version = dependency.extension_version
    extension = version.extension
    txt = "#{extension.name} #{version.version}"
    link_to(txt, owner_scoped_extension_url(extension))
  end

  #
  # If we have a linked extension for this dependency, allow the user to get to
  # it. Otherwise, just show the name
  #
  # @param dep [ExtensionDependency]
  #
  # @return [String] The dependency info to show on the page
  #
  def dependency_link(dep)
    name_and_version = "#{dep.name} #{dep.version_constraint}"

    content_tag(:td) do
      if dep.extension
        link_to name_and_version, owner_scoped_extension_url(dep.extension), rel: 'extension_dependency'
      else
        name_and_version
      end
    end
  end

  def is_followable?(extension)
    true
  end

  def is_commitable?(extension)
    extension.github_repo.present?
  end

  #
  # Return the correct state for an extension follow/unfollow button. If given a
  # block, the result of the block will become the button's text.
  #
  # @example
  #   <%= follow_button_for(@extension) %>
  #   <%= follow_button_for(@extension) do |following| %>
  #     <%= following ? 'Stop Following' : 'Follow' %>
  #   <% end %>
  #
  # @param extension [Extension] the Extension to follow or unfollow
  # @param params [Hash] any additional query params to add to the follow button
  # @yieldparam following [Boolean] whether or not the +current_user+ is
  #   following the given +Extension+
  #
  # @return [String] a link based on the following state for the current extension.
  #
  def follow_button_for(extension, params = {}, &block)
    fa_icon = content_tag(:i, '', class: 'fa fa-star')
    followers_count = extension.extension_followers_count.to_s
    followers_count_span = content_tag(
      :span,
      number_with_delimiter(followers_count),
      class: 'extension_follow_count'
    )
    follow_html = fa_icon + 'Star' + followers_count_span
    unfollow_html = fa_icon + 'Starred' + followers_count_span

    unless current_user
      return link_to(
        follow_extension_path(extension, params.merge(username: extension.owner_name)),
        method: 'put',
        rel: 'sign-in-to-follow',
        class: 'button radius tiny secondary follow',
        title: "You must be signed in to star #{t('indefinite_articles.extension')} #{t('nouns.extension')}.",
        'data-tooltip' => true
      ) do
        if block
          block.call(false)
        else
          follow_html
        end
      end
    end

    if extension.followed_by?(current_user)
      link_to(
        unfollow_extension_path(extension, params.merge(username: extension.owner_name)),
        method: 'delete',
        rel: 'unfollow',
        class: 'button radius tiny secondary follow',
        id: 'unfollow_extension',
        'data-extension' => extension.lowercase_name,
        remote: true
      ) do
        if block
          block.call(true)
        else
          unfollow_html
        end
      end
    else
      link_to(
        follow_extension_path(extension, params.merge(username: extension.owner_name)),
        method: 'put',
        rel: 'follow',
        class: 'button radius tiny follow',
        id: 'follow_extension',
        'data-extension' => extension.lowercase_name,
        remote: true
      ) do
        if block
          block.call(false)
        else
          follow_html
        end
      end
    end
  end

  #
  # Generates a link to the current page with a parameter to sort extensions in
  # a particular way.
  #
  # @param linked_text [String] the contents of the +a+ tag
  # @param ordering [String] the name of the ordering
  #
  # @example
  #   link_to_sorted_extensions 'Recently Updated', 'recently_updated'
  #
  # @return [String] the generated anchor tag
  #
  def link_to_sorted_extensions(linked_text, ordering)
    if params[:order] == ordering
      link_to linked_text, params.to_unsafe_h.except(:order), class: 'button radius secondary tiny active'
    else
      link_to linked_text, params.to_unsafe_h.merge(order: ordering), class: 'button radius secondary tiny'
    end
  end

  #
  # Highlight given code
  #
  # @param src [String] the source code
  # @param lang [String] language the code is written in
  #
  # @return [String] generated pre tag
  #
  def highlight_code(code, lang)
    lexer = Rouge::Lexer.find(lang)
    theme = Rouge::Themes::Github.new
    highl = Rouge.highlight(code, lexer, Rouge::Formatters::HTMLInline.new(theme))
    highl.html_safe
  rescue Timeout::Error => _
    nil
  end

  #
  # Given asset version returns sensuctl compatible asset definition
  #
  # @param version [ExtensionVersion] version record of the extension
  # @param format [String] format in either 'yaml' or 'json'
  #
  # @return [String] asset definition
  #
  def to_asset_definition(version, format: "yaml")
    ctrl = @_controller
    resp = ctrl.render_to_string(template: 'api/v1/release_assets/index.json.jbuilder', assigns: {version: version})
    resp = YAML.dump(JSON.parse(resp)) if format == "yaml"
    resp
  end

  def compilation_errors(extension, version=nil)
    errors = []
    if extension.compilation_error.present?
      errors << "Extension: #{extension.compilation_error}"
    end
    versions = extension.extension_versions.select(:id, :version, :compilation_error).where.not(compilation_error: nil)
    versions = versions.where(id: version.id) if version.present?
    versions.each do |version|
      errors << "Version #{version.version}: #{version.compilation_error}"
    end
    errors
  end

  def compilation_status(extension, job_ids)
    job_count = @job_ids.length
    pending, retrying, complete, failed = 0.0, 0.0, 0.0, 0.0
    jobs_failed, jobs_retrying = [], []

    @job_ids.each do |job, key|

      status = Sidekiq::Status::status(key)

      case status
        when :queued, :working
          pending += 1
        when :retrying
          retrying += 1
          jobs_retrying << job
        when :complete
          complete += 1
          # puts status
        when :failed, :interrupted
          failed += 1
          jobs_failed << job
        else
      end
    end

    percent_complete = ((complete / job_count) * 100).round(2)

    html = ''
    klass = 'compilation-complete'
    if failed > 0
      html += content_tag("div", raw("<b>Compilations failed:</b> #{jobs_failed.join(', ')}"), class: 'compilation-notice')
      klass = 'compilation-failed'
    end
    if retrying > 0
      html += content_tag("div", raw("<b>Retrying Compilations:</b> #{jobs_retrying.join(', ')}"), class: 'compilation-notice')
       klass = 'compilation-retry'
    end
    html += content_tag('div', raw("<b>Compiling Extension % #{percent_complete} Complete</b>"), class: 'compilation-notice')

    if percent_complete == 100
      redis_pool.with do |redis|
        redis.del("compile.extension;#{extension.id};status")
      end
    end

    content_tag('div', raw(html), class: klass )

  end

  #
  # Selects the appropriate avatar
  # only link if the avatar is that of the owner
  # only show organization avatar for hosted assets
  #
  # @param extension [active record]
  # @param options [Hash] options for the Gravatar
  # @option options [Integer] :size (48) the size of the Gravatar in pixels
  # @option options [String] :maintainer the id to associate with the gravatar
  #
  def link_to_gravatar(extension, options={})
    options = {
      size: 36
    }.merge(options)

    size = options[:size]
    maintainer = options[:maintainer] || ''
    html = ''

    if extension.github_organization
      html = gravatar_for(extension.github_organization, size: size)
    elsif extension.hosted?
      html = gravatar_for(extension.owner, size: size, hosted: true)
    else
      link_to extension.owner do
        html = gravatar_for(extension.owner, size: size)
        html += content_tag('div', maintainer) if maintainer.present?
      end
    end
    html.html_safe
  end

  # Resolves the host
  # Selects the message
  # @param extension_version [active record]
  def link_to_suggested_asset(version)
    message = version.annotation('suggested_message')
    message ||= 'Preference should be given to this upstream asset.'
    url = URI(version.annotation('suggested_asset_url'))
    # force local only.
    url.scheme = request.scheme
    url.host = request.host
    link_to message, url.to_s, target: '_blank'
  end
end

