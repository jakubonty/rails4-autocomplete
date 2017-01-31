module Rails4Autocomplete
  module Orm
    module ActiveRecord
      def get_autocomplete_order(method, options, model=nil)
        order = options[:order]

        table_prefix = model ? "#{ options[:table_name] ||= model.table_name}." : ""
        order || "#{table_prefix}#{method} ASC"
      end

      def get_autocomplete_items(parameters)
        model   = parameters[:model]
        table_name = parameters[:table_name]
        term    = parameters[:term]
        method  = parameters[:method]
        options = parameters[:options]
        scopes  = Array(options[:scopes])
        where   = options[:where]
        limit   = get_autocomplete_limit(options)
        order   = get_autocomplete_order(method, options, model)

        items = model.all

        scopes.each { |scope| items = items.send(scope) } unless scopes.empty?

        items = items.select(get_autocomplete_select_clause(model, method, options)) unless options[:full_model]
        items = items.where(get_autocomplete_where_clause(model, term, method, options)).
            limit(limit).order(order)
        items = items.where(where) unless where.blank?

        items.to_a
      end

      def get_autocomplete_select_clause(model, method, options)
        table_name = model.table_name
        (["#{table_name}.#{model.primary_key}", "#{options[:table_name]}.#{method}"] + (options[:extra_data].blank? ? [] : options[:extra_data]))
      end

      def get_autocomplete_where_clause(model, term, method, options)
        table_name = model.table_name
        term = term.gsub(/([_%\\])/, '\\\\\1')
        is_full_search = options[:full]
        like_clause = (postgres?(model) ? 'ILIKE' : 'LIKE')
        term_clause = ["#{(is_full_search ? '%' : '')}#{term.downcase}%"]
        if (search_params = options[:search_params])
          search_param = []
          search_params.each do |param|
            search_param << get_autocomplete_like_clause(get_autocomplete_search_param(table_name, param), like_clause)
          end
          term_clause = term_clause * search_params.count
          search_param = search_param.join(' OR ')
        else
          search_param = get_autocomplete_like_clause(get_autocomplete_search_param(table_name, method), like_clause)
        end
        [search_param].concat(term_clause)
      end

      def get_autocomplete_search_param(table, param)
        "#{table}.#{param}"
      end

      def get_autocomplete_like_clause(param, like_clause)
        "LOWER(#{param}) #{like_clause} ?"
      end

      def postgres?(model)
        # Figure out if this particular model uses the PostgreSQL adapter
        model.connection.class.to_s.match(/PostgreSQLAdapter/)
      end
    end
  end
end
