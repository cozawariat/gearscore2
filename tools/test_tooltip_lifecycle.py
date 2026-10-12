"""Run tooltip lifecycle regression checks with Lua 5.1 (pip install lupa)."""

import pathlib
import unittest

from lupa.lua51 import LuaRuntime

ROOT = pathlib.Path(__file__).resolve().parents[1]


class TooltipLifecycleTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute('''
            GS2 = { State = { ExplainState = {} } }
            function tooltip()
                return { shown = true, link = "item:1", hooks = {},
                    IsShown = function(self) return self.shown end,
                    Hide = function(self) self.shown = false end,
                    GetItem = function(self) return "Item", self.link end,
                    HookScript = function(self, event, callback) self.hooks[event] = callback end }
            end
            GameTooltip = tooltip()
            ShoppingTooltip1 = tooltip()
            ShoppingTooltip2 = tooltip()
            ItemRefTooltip = tooltip()
            GS_ExplainTooltip = tooltip()
            IsEquippableItem = function(link) return link == "item:1" end
        ''')
        self.lua.execute((ROOT / 'UI/TooltipLogic.lua').read_text(encoding='utf-8'))
        source = (ROOT / 'UI/MainUI.lua').read_text(encoding='utf-8')
        start = source.index('for _, tooltip in ipairs({ GameTooltip, ShoppingTooltip1')
        end = source.index('\nend', start) + len('\nend')
        self.lua.execute(source[start:end])

    def test_clear_and_hide_all_supported_owners(self):
        self.lua.execute('''
            for _, owner in ipairs({GameTooltip, ShoppingTooltip1, ShoppingTooltip2, ItemRefTooltip}) do
                for _, event in ipairs({"OnHide", "OnTooltipCleared"}) do
                    GS_ExplainTooltip.shown = true
                    GS2.State.ExplainState.owner = owner
                    GS2.State.ExplainState.itemLink = "item:1"
                    GS2.State.ExplainState.itemSlot = 5
                    owner.hooks[event](owner)
                    assert(not GS_ExplainTooltip:IsShown())
                    assert(next(GS2.State.ExplainState) == nil)
                end
            end
        ''')

    def test_unrelated_comparison_clear_preserves_owner(self):
        self.lua.execute('''
            GS2.State.ExplainState.owner = GameTooltip
            ShoppingTooltip1.hooks.OnTooltipCleared(ShoppingTooltip1)
            ShoppingTooltip2.hooks.OnHide(ShoppingTooltip2)
            assert(GS_ExplainTooltip:IsShown())
            assert(GS2.State.ExplainState.owner == GameTooltip)
        ''')

    def test_stale_render_stops_before_scoring(self):
        self.lua.execute('''
            GS2.State.ExplainState.owner = GameTooltip
            GameTooltip.link = "item:2"
            GS_GetItemData = function() error("Stale item reached scoring") end
            GS_RenderExplainTooltip(GameTooltip, "item:1")
            assert(not GS_ExplainTooltip:IsShown())
            assert(GS2.State.ExplainState.owner == nil)
        ''')

    def test_ctrl_retry_without_item_or_with_hidden_owner(self):
        self.lua.execute('''
            for _, scenario in ipairs({"achievement", "nongear", "hidden"}) do
                GS_ExplainTooltip.shown = true
                GS2.State.ExplainState.owner = GameTooltip
                GameTooltip.shown = scenario ~= "hidden"
                GameTooltip.link = scenario == "nongear" and "item:bag" or nil
                GS_TryShowExplainFromOwner(GameTooltip)
                assert(not GS_ExplainTooltip:IsShown())
                assert(GS2.State.ExplainState.owner == nil)
            end
        ''')

    def test_ctrl_retry_with_current_item_renders(self):
        self.lua.execute('''
            local calls = 0
            GS_RenderExplainTooltip = function(owner, link)
                assert(owner == GameTooltip and link == "item:1")
                calls = calls + 1
            end
            GS_TryShowExplainFromOwner(GameTooltip)
            assert(calls == 1)
        ''')


if __name__ == '__main__':
    unittest.main()
