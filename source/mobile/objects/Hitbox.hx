/*
 * Copyright (C) 2025 Mobile Porting Team
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 */

package mobile.objects;

import openfl.display.BitmapData;
import openfl.display.Shape;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxSignal.FlxTypedSignal;
import openfl.geom.Matrix;
import objects.Note;

class Hitbox extends MobileInputManager implements IMobileControls
{
	/**
	 * Layouts ported from the official V-Slice mobile HUD (`FunkinHitbox`).
	 */
	public static final vsliceSchemes:Array<String> = [
		'Four Lanes',
		'Double Thumb Triangle',
		'Double Thumb Square',
		'Double Thumb DPad',
		'Arrows'
	];

	/**
	 * Every selectable scheme, `Classic` being the original Psych Mobile hitbox.
	 */
	public static final allSchemes:Array<String> = [
		'Classic',
		'Four Lanes',
		'Double Thumb Triangle',
		'Double Thumb Square',
		'Double Thumb DPad',
		'Arrows'
	];

	static final directionColors:Array<Int> = [0xFFC24B99, 0xFF00FFFF, 0xFF12FA05, 0xFFF9393F];
	static final directionIDs:Array<Array<MobileInputID>> = [
		[MobileInputID.HITBOX_LEFT, MobileInputID.NOTE_LEFT],
		[MobileInputID.HITBOX_DOWN, MobileInputID.NOTE_DOWN],
		[MobileInputID.HITBOX_UP, MobileInputID.NOTE_UP],
		[MobileInputID.HITBOX_RIGHT, MobileInputID.NOTE_RIGHT]
	];

	/**
	 * Second hints of the double thumb schemes, indexed by direction (left, down, up, right).
	 * They share the IDs of the primary hint (`buttonLeft`, `buttonDown`...).
	 */
	var mirrorHints:Array<Array<TouchButton>> = [[], [], [], []];

	/**
	 * `true` when the current scheme has a second hint per direction (the double thumb ones).
	 * Lets `checkStatusUnsafe` skip the mirror lookup entirely on every other scheme.
	 */
	var hasMirrors:Bool = false;

	/**
	 * Graphics built while the scheme is being created, so the mirrored hints of the double thumb
	 * schemes reuse the same bitmap instead of drawing an identical one. Cleared once the layout is built.
	 */
	var graphicCache:Map<String, FlxGraphic> = new Map<String, FlxGraphic>();

	final offsetFir:Int = (ClientPrefs.data.hitboxPos ? Std.int(FlxG.height / 4) * 3 : 0);
	final offsetSec:Int = (ClientPrefs.data.hitboxPos ? 0 : Std.int(FlxG.height / 4));

	public var buttonLeft:TouchButton = new TouchButton(0, 0, [MobileInputID.HITBOX_LEFT, MobileInputID.NOTE_LEFT]);
	public var buttonDown:TouchButton = new TouchButton(0, 0, [MobileInputID.HITBOX_DOWN, MobileInputID.NOTE_DOWN]);
	public var buttonUp:TouchButton = new TouchButton(0, 0, [MobileInputID.HITBOX_UP, MobileInputID.NOTE_UP]);
	public var buttonRight:TouchButton = new TouchButton(0, 0, [MobileInputID.HITBOX_RIGHT, MobileInputID.NOTE_RIGHT]);
	public var buttonExtra:TouchButton = new TouchButton(0, 0, [MobileInputID.EXTRA_1]);
	public var buttonExtra2:TouchButton = new TouchButton(0, 0, [MobileInputID.EXTRA_2]);

	public var instance:MobileInputManager;
	public var onButtonDown:FlxTypedSignal<TouchButton->Void> = new FlxTypedSignal<TouchButton->Void>();
	public var onButtonUp:FlxTypedSignal<TouchButton->Void> = new FlxTypedSignal<TouchButton->Void>();

	var storedButtonsIDs:Map<String, Array<MobileInputID>> = new Map<String, Array<MobileInputID>>();

	public function new(?extraMode:ExtraActions = NONE)
	{
		super();

		for (button in Reflect.fields(this))
		{
			var field = Reflect.field(this, button);
			if (Std.isOfType(field, TouchButton))
				storedButtonsIDs.set(button, Reflect.getProperty(field, 'IDs'));
		}

		if (vsliceSchemes.contains(ClientPrefs.data.hitboxScheme))
			buildVSliceScheme(ClientPrefs.data.hitboxScheme, extraMode);
		else switch (extraMode)
		{
			case NONE:
				add(buttonLeft = createHint(0, 0, Std.int(FlxG.width / 4), FlxG.height, 0xFFC24B99));
				add(buttonDown = createHint(FlxG.width / 4, 0, Std.int(FlxG.width / 4), FlxG.height, 0xFF00FFFF));
				add(buttonUp = createHint(FlxG.width / 2, 0, Std.int(FlxG.width / 4), FlxG.height, 0xFF12FA05));
				add(buttonRight = createHint((FlxG.width / 2) + (FlxG.width / 4), 0, Std.int(FlxG.width / 4), FlxG.height, 0xFFF9393F));

			case SINGLE:
				add(buttonLeft = createHint(0, offsetSec, Std.int(FlxG.width / 4), Std.int(FlxG.height / 4) * 3, 0xFFC24B99));
				add(buttonDown = createHint(FlxG.width / 4, offsetSec, Std.int(FlxG.width / 4), Std.int(FlxG.height / 4) * 3, 0xFF00FFFF));
				add(buttonUp = createHint(FlxG.width / 2, offsetSec, Std.int(FlxG.width / 4), Std.int(FlxG.height / 4) * 3, 0xFF12FA05));
				add(buttonRight = createHint((FlxG.width / 2) + (FlxG.width / 4), offsetSec, Std.int(FlxG.width / 4), Std.int(FlxG.height / 4) * 3, 0xFFF9393F));
				add(buttonExtra = createHint(0, offsetFir, FlxG.width, Std.int(FlxG.height / 4), 0xFF0066FF));

			case DOUBLE:
				add(buttonLeft = createHint(0, offsetSec, Std.int(FlxG.width / 4), Std.int(FlxG.height / 4) * 3, 0xFFC24B99));
				add(buttonDown = createHint(FlxG.width / 4, offsetSec, Std.int(FlxG.width / 4), Std.int(FlxG.height / 4) * 3, 0xFF00FFFF));
				add(buttonUp = createHint(FlxG.width / 2, offsetSec, Std.int(FlxG.width / 4), Std.int(FlxG.height / 4) * 3, 0xFF12FA05));
				add(buttonRight = createHint((FlxG.width / 2) + (FlxG.width / 4), offsetSec, Std.int(FlxG.width / 4), Std.int(FlxG.height / 4) * 3, 0xFFF9393F));
				add(buttonExtra2 = createHint(Std.int(FlxG.width / 2), offsetFir, Std.int(FlxG.width / 2), Std.int(FlxG.height / 4), 0xA6FF00));
				add(buttonExtra = createHint(0, offsetFir, Std.int(FlxG.width / 2), Std.int(FlxG.height / 4), 0xFF0066FF));
		}

		for (button in Reflect.fields(this))
		{
			if (Std.isOfType(Reflect.field(this, button), TouchButton))
				Reflect.setProperty(Reflect.getProperty(this, button), 'IDs', storedButtonsIDs.get(button));
		}

		storedButtonsIDs.clear();

		for (i in 0...mirrorHints.length)
		{
			for (mirror in mirrorHints[i])
			{
				mirror.IDs = directionIDs[i].copy();
				hasMirrors = true;
			}
		}

		// The sprites hold their own reference to the graphics now, the cache is no longer needed
		graphicCache.clear();

		scrollFactor.set();
		updateTrackedButtons();

		instance = this;
	}

	/**
	 * Double thumb schemes have two hints for the same note direction, so a direction counts as
	 * pressed/just pressed/just released if any of its hints is, and as released only if all of them are.
	 */
	override function checkStatusUnsafe(button:MobileInputID, state:mobile.input.MobileInputManager.ButtonsStates = JUST_PRESSED):Bool
	{
		final primary:Bool = super.checkStatusUnsafe(button, state);

		// Every scheme except the double thumb ones, this runs for every key on every frame
		if (!hasMirrors)
			return primary;

		var direction:Int = -1;
		for (i in 0...directionIDs.length)
		{
			if (directionIDs[i].contains(button))
			{
				direction = i;
				break;
			}
		}

		if (direction < 0 || mirrorHints[direction].length == 0)
			return primary;

		final wantsReleased:Bool = switch (state)
		{
			case RELEASED: true;
			default: false;
		}

		if (wantsReleased)
		{
			if (!primary)
				return false;

			for (mirror in mirrorHints[direction])
				if (!mirror.released)
					return false;

			return true;
		}

		if (primary)
			return true;

		for (mirror in mirrorHints[direction])
		{
			final value:Bool = switch (state)
			{
				case JUST_PRESSED: mirror.justPressed;
				case JUST_RELEASED: mirror.justReleased;
				case PRESSED: mirror.pressed;
				case RELEASED: mirror.released;
			}

			if (value)
				return true;
		}

		return false;
	}

	/**
	 * Copies the color of every primary hint to its mirror hints (called after the colors are set).
	 */
	public function syncMirrorColors():Void
	{
		final primaries:Array<TouchButton> = [buttonLeft, buttonDown, buttonUp, buttonRight];

		for (i in 0...mirrorHints.length)
		{
			for (mirror in mirrorHints[i])
			{
				mirror.color = primaries[i].color;
				mirror.label.color = primaries[i].label.color;
				mirror.label.updateColorTransform();
			}
		}
	}

	override function destroy()
	{
		super.destroy();
		onButtonUp.destroy();
		onButtonDown.destroy();

		for (fieldName in Reflect.fields(this))
		{
			var field = Reflect.field(this, fieldName);
			if (Std.isOfType(field, TouchButton))
				Reflect.setField(this, fieldName, FlxDestroyUtil.destroy(field));
		}
	}

	private function createHint(X:Float, Y:Float, Width:Int, Height:Int, Color:Int = 0xFFFFFF):TouchButton
	{
		var hint = new TouchButton(X, Y);
		hint.statusAlphas = [];
		hint.statusIndicatorType = NONE;
		hint.loadGraphic(createHintGraphic(Width, Height));

		hint.label = new FlxSprite();
		hint.label.loadGraphic(createHintGraphic(Width, Math.floor(Height * 0.035), true));

		if (ClientPrefs.data.hitboxPos)
			hint.label.offset.y -= (hint.height - hint.label.height) / 2;
		else
			hint.label.offset.y += (hint.height - hint.label.height) / 2;

		hint.labelStatusDiff = 0;
		hint.label.alpha = 0;
		hint.label.visible = false;

		if (ClientPrefs.data.hitboxType != "Hidden")
		{
			var hintTween:FlxTween = null;

			hint.onDown.callback = function()
			{
				onButtonDown.dispatch(hint);

				if (hintTween != null)
					hintTween.cancel();

				hintTween = FlxTween.tween(hint, {alpha: ClientPrefs.data.controlsAlpha}, ClientPrefs.data.controlsAlpha / 100, {
					ease: FlxEase.circInOut,
					onComplete: (twn:FlxTween) -> hintTween = null
				});
			}

			hint.onOut.callback = hint.onUp.callback = function()
			{
				onButtonUp.dispatch(hint);

				if (hintTween != null)
					hintTween.cancel();

				hintTween = FlxTween.tween(hint, {alpha: 0}, ClientPrefs.data.controlsAlpha / 10, {
					ease: FlxEase.circInOut,
					onComplete: (twn:FlxTween) -> hintTween = null
				});
			}
		}
		else
		{
			hint.onDown.callback = () -> onButtonDown.dispatch(hint);
			hint.onOut.callback = hint.onUp.callback = () -> onButtonUp.dispatch(hint);
		}

		hint.immovable = hint.multiTouch = true;
		hint.solid = hint.moves = false;
		hint.alpha = 0;
		hint.canChangeLabelAlpha = false;
		hint.label.antialiasing = hint.antialiasing = ClientPrefs.data.antialiasing;
		hint.color = Color;

		#if FLX_DEBUG
		hint.ignoreDrawDebug = true;
		#end

		return hint;
	}

	function createHintGraphic(Width:Int, Height:Int, ?isLane:Bool = false):FlxGraphic
	{
		var shape:Shape = new Shape();
		shape.graphics.beginFill(0xFFFFFF);

		if (ClientPrefs.data.hitboxType == "No Gradient")
		{
			var matrix:Matrix = new Matrix();
			matrix.createGradientBox(Width, Height, 0, 0, 0);

			if (isLane)
				shape.graphics.beginFill(0xFFFFFF);
			else
				shape.graphics.beginGradientFill(RADIAL, [0xFFFFFF, 0xFFFFFF], [0, 1], [60, 255], matrix, PAD, RGB, 0);

			shape.graphics.drawRect(0, 0, Width, Height);
			shape.graphics.endFill();
		}
		else if (ClientPrefs.data.hitboxType == "No Gradient (Old)")
		{
			shape.graphics.lineStyle(10, 0xFFFFFF, 1);
			shape.graphics.drawRect(0, 0, Width, Height);
			shape.graphics.endFill();
		}
		else
		{
			shape.graphics.lineStyle(3, 0xFFFFFF, 1);
			shape.graphics.drawRect(0, 0, Width, Height);
			shape.graphics.lineStyle(0, 0, 0);
			shape.graphics.drawRect(3, 3, Width - 6, Height - 6);
			shape.graphics.endFill();

			if (isLane)
				shape.graphics.beginFill(0xFFFFFF);
			else
				shape.graphics.beginGradientFill(RADIAL, [0xFFFFFF, FlxColor.TRANSPARENT], [1, 0], [0, 255], null, null, null, 0.5);

			shape.graphics.drawRect(3, 3, Width - 6, Height - 6);
			shape.graphics.endFill();
		}

		var bitmap:BitmapData = new BitmapData(Width, Height, true, 0);
		bitmap.draw(shape);

		return FlxG.bitmap.add(bitmap);
	}

	// ------------------------------------------------------------------------------------------
	// V-Slice mobile HUD (ported from `funkin.mobile.ui.FunkinHitbox` of the official repo)
	// ------------------------------------------------------------------------------------------

	/**
	 * Builds one of the V-Slice layouts. The extra buttons keep working: when enabled they take a
	 * strip of a quarter of the screen (top or bottom, depending on `hitboxPos`) and the layout
	 * is fitted in the remaining area.
	 */
	function buildVSliceScheme(scheme:String, extraMode:ExtraActions):Void
	{
		final quarter:Int = Std.int(FlxG.height / 4);
		var areaY:Int = 0;
		var areaH:Int = FlxG.height;

		switch (extraMode)
		{
			case SINGLE:
				areaY = offsetSec;
				areaH = quarter * 3;
				add(buttonExtra = createHint(0, offsetFir, FlxG.width, quarter, 0xFF0066FF));
			case DOUBLE:
				areaY = offsetSec;
				areaH = quarter * 3;
				add(buttonExtra2 = createHint(Std.int(FlxG.width / 2), offsetFir, Std.int(FlxG.width / 2), quarter, 0xA6FF00));
				add(buttonExtra = createHint(0, offsetFir, Std.int(FlxG.width / 2), quarter, 0xFF0066FF));
			case NONE:
		}

		final half:Int = Std.int(FlxG.width / 2);

		switch (scheme)
		{
			case 'Four Lanes':
				final laneWidth:Int = Std.int(FlxG.width / 4);

				for (i in 0...4)
					registerHint(i, createLaneHint(i * laneWidth, areaY, laneWidth, areaH, true), false);

			case 'Double Thumb Triangle':
				final quarterWidth:Int = Std.int(FlxG.width / 4);
				final halfHeight:Int = Std.int(areaH / 2);

				for (i in 0...2)
				{
					final xOffset:Int = (i == 1) ? half : 0;
					final mirror:Bool = i == 1;

					registerHint(0, createTriangleHint(xOffset, areaY, quarterWidth, areaH, 0), mirror);
					registerHint(1, createTriangleHint(xOffset, areaY + halfHeight, half, halfHeight, 1), mirror);
					registerHint(2, createTriangleHint(xOffset, areaY, half, halfHeight, 2), mirror);
					registerHint(3, createTriangleHint(xOffset + quarterWidth, areaY, quarterWidth, areaH, 3), mirror);
				}

			case 'Double Thumb Square':
				final hintWidth:Int = Std.int(FlxG.width / 8);
				final boxWidth:Int = hintWidth * 2;
				final boxHeight:Int = Std.int(areaH / 2);

				for (i in 0...2)
				{
					final xOffset:Int = (i == 1) ? half : 0;

					for (j in 0...4)
					{
						var hint:TouchButton;

						if (j == 1 || j == 2)
							hint = createLaneHint(xOffset + hintWidth, areaY + (j == 1 ? boxHeight : 0), boxWidth, boxHeight, false);
						else
							hint = createLaneHint(xOffset + (j == 0 ? 0 : hintWidth + boxWidth), areaY, hintWidth, areaH, false);

						registerHint(j, hint, i == 1);
					}
				}

			case 'Double Thumb DPad':
				final hintSize:Int = 75;
				final outlineThickness:Int = 5;
				final zoneRadius:Int = 115;
				final angles:Array<Float> = [Math.PI, Math.PI / 2, Math.PI * 1.5, 0];

				for (i in 0...2)
				{
					for (j in 0...4)
					{
						final x:Float = ((i == 1) ? FlxG.width - (hintSize * 4) : hintSize * 2) + Math.cos(angles[j]) * zoneRadius;
						final y:Float = (areaY + areaH - (hintSize * 3.75)) + Math.sin(angles[j]) * zoneRadius;

						registerHint(j, createCircleHint(x, y, hintSize, outlineThickness), i == 1);
					}
				}

			case 'Arrows':
				final hintWidth:Int = 146;
				final hintHeight:Int = 149;
				final noteSpacing:Int = 80;

				final xPos:Int = Std.int((FlxG.width - (hintWidth + noteSpacing) * 4) / 2);
				final yPos:Int = areaY + areaH - hintHeight * 2 - 24;

				for (i in 0...4)
					registerHint(i, createArrowHint(xPos + i * (hintWidth + noteSpacing), yPos, i, hintWidth, hintHeight), false);
		}
	}

	/**
	 * Stores a hint as the primary hint of its direction (or as a mirror of it) and adds it to the group.
	 * @param direction 0 = left, 1 = down, 2 = up, 3 = right
	 */
	function registerHint(direction:Int, hint:TouchButton, mirror:Bool):Void
	{
		hint.color = directionColors[direction];
		hint.label.color = directionColors[direction];

		if (mirror)
		{
			mirrorHints[direction].push(hint);
		}
		else
		{
			switch (direction)
			{
				case 0:
					buttonLeft = hint;
				case 1:
					buttonDown = hint;
				case 2:
					buttonUp = hint;
				default:
					buttonRight = hint;
			}
		}

		add(hint);
	}

	/**
	 * Returns the graphic stored under `key`, building it with `build` the first time it is requested.
	 */
	function cachedGraphic(key:String, build:Void->FlxGraphic):FlxGraphic
	{
		var graphic:FlxGraphic = graphicCache.get(key);

		if (graphic == null)
		{
			graphic = build();
			graphicCache.set(key, graphic);
		}

		return graphic;
	}

	function createLaneHint(X:Float, Y:Float, Width:Int, Height:Int, withLabel:Bool):TouchButton
	{
		final graphic:FlxGraphic = cachedGraphic('rect:$Width:$Height', () -> createVSliceRectGraphic(Width, Height));
		final labelGraphic:FlxGraphic = withLabel ? cachedGraphic('label:$Width:$Height',
			() -> createVSliceLaneLabelGraphic(Width, Height, Math.floor(Height * 0.035))) : null;
		return createVSliceHint(X, Y, graphic, labelGraphic, false);
	}

	function createTriangleHint(X:Float, Y:Float, Width:Int, Height:Int, direction:Int):TouchButton
	{
		final vertices:Array<Float> = getTriangleVertices(Width, Height, direction);
		final graphic:FlxGraphic = cachedGraphic('triangle:$Width:$Height:$direction', () -> createVSliceTriangleGraphic(Width, Height, vertices));
		final hint:TouchButton = createVSliceHint(X, Y, graphic, null, false);
		hint.polygon = vertices;
		return hint;
	}

	function createCircleHint(X:Float, Y:Float, Radius:Int, Outline:Int):TouchButton
	{
		final graphic:FlxGraphic = cachedGraphic('circle:$Radius:$Outline', () -> createVSliceCircleGraphic(Radius, Outline));
		final hint:TouchButton = createVSliceHint(X, Y, graphic, null, true);
		hint.radius = Radius;
		return hint;
	}

	function createArrowHint(X:Float, Y:Float, direction:Int, Width:Int, Height:Int):TouchButton
	{
		final names:Array<String> = ['LEFT', 'DOWN', 'UP', 'RIGHT'];

		final hint:TouchButton = new TouchButton(X, Y);
		hint.statusAlphas = [];
		hint.statusIndicatorType = NONE;
		hint.frames = Paths.getSparrowAtlas(Note.defaultNoteSkin);
		hint.animation.addByPrefix('static', 'arrow' + names[direction]);
		hint.animation.addByPrefix('pressed', names[direction].toLowerCase() + ' press', 24, false);
		hint.animation.play('static', true);
		hint.setGraphicSize(Std.int(hint.width * 0.7));
		hint.updateHitbox();
		hint.setSize(Width, Height);
		hint.centerOffsets();
		hint.centerOrigin();

		hint.label = new FlxSprite();
		hint.label.makeGraphic(1, 1, 0x00FFFFFF);
		hint.labelStatusDiff = 0;
		hint.canChangeLabelAlpha = false;
		hint.label.alpha = 0;
		hint.immovable = hint.multiTouch = true;
		hint.solid = hint.moves = false;
		hint.antialiasing = ClientPrefs.data.antialiasing;
		hint.alpha = 0;

		#if FLX_DEBUG
		hint.ignoreDrawDebug = true;
		#end

		final hidden:Bool = ClientPrefs.data.hitboxType == 'Hidden';
		final maxAlpha:Float = ClientPrefs.data.controlsAlpha;
		final idleAlpha:Float = hidden ? 0 : maxAlpha * 0.6;
		final pressAlpha:Float = hidden ? 0 : maxAlpha;
		hint.alpha = idleAlpha;

		function setPressed(pressed:Bool):Void
		{
			hint.animation.play(pressed ? 'pressed' : 'static', true);
			hint.centerOrigin();
			hint.centerOffsets();
			hint.alpha = pressed ? pressAlpha : idleAlpha;
		}

		hint.onDown.callback = function()
		{
			onButtonDown.dispatch(hint);
			setPressed(true);
		}

		hint.onOut.callback = hint.onUp.callback = function()
		{
			onButtonUp.dispatch(hint);
			setPressed(false);
		}

		return hint;
	}

	/**
	 * Shared setup of every V-Slice hint: invisible until pressed (or dimmed when pressed for the visible ones)
	 * with the same fade tweens as the official `FunkinHint`.
	 * @param visibleStyle `true` for hints that stay visible and dim when pressed (the DPad ones).
	 */
	function createVSliceHint(X:Float, Y:Float, graphic:FlxGraphic, labelGraphic:FlxGraphic, visibleStyle:Bool):TouchButton
	{
		final hint:TouchButton = new TouchButton(X, Y);
		hint.statusAlphas = [];
		hint.statusIndicatorType = NONE;
		hint.loadGraphic(graphic);

		final hasLabel:Bool = labelGraphic != null;
		hint.label = new FlxSprite();

		if (hasLabel)
			hint.label.loadGraphic(labelGraphic);
		else
			hint.label.makeGraphic(1, 1, 0x00FFFFFF);

		hint.labelStatusDiff = 0;
		hint.canChangeLabelAlpha = false;
		hint.label.alpha = 0;
		hint.label.antialiasing = hint.antialiasing = ClientPrefs.data.antialiasing;
		hint.immovable = hint.multiTouch = true;
		hint.solid = hint.moves = false;
		hint.alpha = 0;

		#if FLX_DEBUG
		hint.ignoreDrawDebug = true;
		#end

		if (ClientPrefs.data.hitboxType == 'Hidden')
		{
			hint.onDown.callback = () -> onButtonDown.dispatch(hint);
			hint.onOut.callback = hint.onUp.callback = () -> onButtonUp.dispatch(hint);
			return hint;
		}

		final maxAlpha:Float = ClientPrefs.data.controlsAlpha;
		final idleAlpha:Float = visibleStyle ? maxAlpha : 0;
		final pressAlpha:Float = visibleStyle ? maxAlpha * 0.5 : maxAlpha;
		final labelIdleAlpha:Float = maxAlpha * 0.5;
		final fadeTime:Float = visibleStyle ? 0.08 : 0.01;

		var hintTween:FlxTween = null;
		var labelTween:FlxTween = null;

		function fade(targetAlpha:Float, targetLabelAlpha:Float):Void
		{
			// The hints that are hidden while idle faded in 0.01s, which is shorter than a frame: set the alpha
			// directly instead of allocating tweens and closures on every single press.
			if (!visibleStyle)
			{
				hint.alpha = targetAlpha;

				if (hasLabel)
					hint.label.alpha = targetLabelAlpha;

				return;
			}

			if (hintTween != null)
				hintTween.cancel();

			hintTween = FlxTween.tween(hint, {alpha: targetAlpha}, fadeTime, {
				ease: FlxEase.circInOut,
				onComplete: (twn:FlxTween) -> hintTween = null
			});

			if (hasLabel)
			{
				if (labelTween != null)
					labelTween.cancel();

				labelTween = FlxTween.tween(hint.label, {alpha: targetLabelAlpha}, fadeTime, {
					ease: FlxEase.circInOut,
					onComplete: (twn:FlxTween) -> labelTween = null
				});
			}
		}

		hint.alpha = idleAlpha;
		if (hasLabel)
			hint.label.alpha = labelIdleAlpha;

		hint.onDown.callback = function()
		{
			onButtonDown.dispatch(hint);
			fade(pressAlpha, 0);
		}

		hint.onOut.callback = hint.onUp.callback = function()
		{
			onButtonUp.dispatch(hint);
			fade(idleAlpha, labelIdleAlpha);
		}

		return hint;
	}

	function createVSliceRectGraphic(Width:Int, Height:Int):FlxGraphic
	{
		final shape:Shape = new Shape();

		switch (ClientPrefs.data.hitboxType)
		{
			case 'No Gradient':
				shape.graphics.beginFill(0xFFFFFF, 1);
			case 'No Gradient (Old)':
				shape.graphics.lineStyle(10, 0xFFFFFF, 1);
			default:
				final matrix:Matrix = new Matrix();
				matrix.createGradientBox(Width, Height, 0, 0, 0);
				shape.graphics.beginGradientFill(RADIAL, [0xFFFFFF, 0xFFFFFF], [0, 1], [60, 255], matrix, PAD, RGB, 0);
		}

		shape.graphics.drawRect(0, 0, Width, Height);
		shape.graphics.endFill();

		final bitmap:BitmapData = new BitmapData(Width, Height, true, 0);
		bitmap.draw(shape);
		return FlxGraphic.fromBitmapData(bitmap, false, null, false);
	}

	function createVSliceLaneLabelGraphic(Width:Int, Height:Int, LabelHeight:Int):FlxGraphic
	{
		final shape:Shape = new Shape();

		final topMatrix:Matrix = new Matrix();
		topMatrix.createGradientBox(Width, LabelHeight, Math.PI / 2, 0, 0);
		shape.graphics.beginGradientFill(LINEAR, [0xFFFFFF, 0xFFFFFF], [1, 0], [0, 255], topMatrix);
		shape.graphics.drawRect(0, 0, Width, LabelHeight);
		shape.graphics.endFill();

		final bottomMatrix:Matrix = new Matrix();
		bottomMatrix.createGradientBox(Width, LabelHeight, Math.PI / 2, 0, Height - LabelHeight);
		shape.graphics.beginGradientFill(LINEAR, [0xFFFFFF, 0xFFFFFF], [0, 1], [0, 255], bottomMatrix);
		shape.graphics.drawRect(0, Height - LabelHeight, Width, LabelHeight);
		shape.graphics.endFill();

		final bitmap:BitmapData = new BitmapData(Width, Height, true, 0);
		bitmap.draw(shape);
		return FlxGraphic.fromBitmapData(bitmap, false, null, false);
	}

	function createVSliceTriangleGraphic(Width:Int, Height:Int, Vertices:Array<Float>):FlxGraphic
	{
		final shape:Shape = new Shape();

		if (ClientPrefs.data.hitboxType == 'No Gradient')
		{
			shape.graphics.beginFill(0xFFFFFF, 1);
		}
		else
		{
			final matrix:Matrix = new Matrix();
			matrix.createGradientBox(Width, Height, 0, 0, 0);
			shape.graphics.beginGradientFill(RADIAL, [0xFFFFFF, 0xFFFFFF], [0, 1], [60, 255], matrix, PAD, RGB, 0);
		}

		shape.graphics.moveTo(Vertices[0], Vertices[1]);
		shape.graphics.lineTo(Vertices[2], Vertices[3]);
		shape.graphics.lineTo(Vertices[4], Vertices[5]);
		shape.graphics.lineTo(Vertices[0], Vertices[1]);
		shape.graphics.endFill();

		final bitmap:BitmapData = new BitmapData(Width, Height, true, 0);
		bitmap.draw(shape);
		return FlxGraphic.fromBitmapData(bitmap, false, null, false);
	}

	function createVSliceCircleGraphic(Radius:Int, Outline:Int):FlxGraphic
	{
		final shape:Shape = new Shape();
		shape.graphics.lineStyle(Outline, 0xFFFFFF, 1);
		shape.graphics.beginFill(0xFFFFFF, 0.35);
		shape.graphics.drawCircle(Radius, Radius, Radius);
		shape.graphics.endFill();

		final matrix:Matrix = new Matrix();
		matrix.translate(Outline, Outline);

		final size:Int = (Radius + Outline) * 2;
		final bitmap:BitmapData = new BitmapData(size, size, true, 0);
		bitmap.draw(shape, matrix);
		return FlxGraphic.fromBitmapData(bitmap, false, null, false);
	}

	/**
	 * Vertices of the triangle of a hint, same shapes as the official V-Slice ones.
	 * @param direction 0 = left, 1 = down, 2 = up, 3 = right
	 */
	function getTriangleVertices(Width:Int, Height:Int, direction:Int):Array<Float>
	{
		// Up and down hints are swapped on purpose, so the triangles form an X with the left and right ones
		if (direction == 2)
			direction = 1;
		else if (direction == 1)
			direction = 2;

		return switch (direction)
		{
			case 2: // pointing up
				[Width / 2, 0, 0, Height, Width, Height];
			case 1: // pointing down
				[0, 0, Width, 0, Width / 2, Height];
			case 0: // pointing left
				[0, 0, Width, Height / 2, 0, Height];
			default: // pointing right
				[Width, 0, 0, Height / 2, Width, Height];
		}
	}
}
