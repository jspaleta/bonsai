//= require vendor/jquery-sparkline

$(function() {
  $(".show-extension-urls-manage, .cancel-submit-urls").click(function(event) {
    event.preventDefault();
    $(".manage-extension-urls").slideToggle();
    $(".show-extension-urls-manage").toggleClass('active');
    $(".extension-urls").fadeToggle();
  });

  $('a[rel~="remove-extension-collaborator"]').on('ajax:success', function(e, data, status, xhr) {
    $(this).parents('.gravatar-container').remove();
  });

  $("a.toggle-details-edit").click(function(event) {
    $(".toggle-details-edit").toggle();
    event.preventDefault();
  });

  $("a.toggle-platforms-edit").click(function(event) {
    $(".toggle-platforms-edit").toggle();
    event.preventDefault();
  });

  $("a.toggle-tags-edit").click(function(event) {
    $(".toggle-tags-edit").toggle();
    event.preventDefault();
  });

  $("a.toggle-collections-edit").click(function(event) {
    $(".toggle-collections-edit").toggle();
    //$("#collections-select-container").css('display', 'block');
    event.preventDefault();
  });

  $(".sparkline").sparkline("html", {
    width: "100%",
    height: "25px",
    spotColor: "",
    spotRadius: 0,
    tooltipFormat: $.spformat('{{prefix}}{{y}}{{suffix}}<span>&nbsp;&nbsp;&nbsp;&nbsp;</span>', 'sparkline-tooltip-class')
  }).addClass("loaded");

  $("#collections-select").select2();

  $("#collections-select").on('select2:select', function (e) {
    const url = $(this).data('url');
    const collection_id = e.params.data.id;
    update_collection(url, collection_id, 'add')
  });

  $("#collections-select").on('select2:unselect', function (e) {
    const url = $(this).data('url');
    const collection_id = e.params.data.id;
    update_collection(url, collection_id, 'remove')
  });

  function update_collection(url, collection_id, update) {

    $.ajax({
      url,
      type: 'PUT',
      data: {
        update: update,
        collection_id: collection_id,
      },
    });
  };

});