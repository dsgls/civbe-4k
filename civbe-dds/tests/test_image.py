from civbe_dds.image import Image


def test_image_holds_its_fields_verbatim():
    rgba = bytes([1, 2, 3, 4] * 4)
    img = Image(width=2, height=2, rgba=rgba, group="Interface")
    assert img.width == 2
    assert img.height == 2
    assert img.rgba == rgba
    assert img.group == "Interface"


def test_group_defaults_are_the_caller_s_choice_not_baked_in():
    # image.py makes no assumption about a default group -- that policy
    # (falling back to "Interface") belongs to write(), not the dataclass.
    img = Image(width=1, height=1, rgba=bytes(4), group="")
    assert img.group == ""
