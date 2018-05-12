## Using Nerves with Rpi3, wifi and Picam.

## Introduction:

A friend of mine asked me about a remote device to monitor a physical machine
in a production line. We discussed about it being able to gather some data
about the performance of the machine, usage and such. I've been thinking about
this problem off and on for a while and eventually wanted to learn more about
Nerves. Maybe this could in fact become a the project my friend and I were
talking and we tackle it professionally. The tools do seem to be there and it
seems like a great learning experience for me.

This guide is somewhat guided towards beginners in the electronics world. I
compiled some notes after looking at Nerves last weekend and during this week.
It's a good exercise to put them together and hopefully someone can benefit
from this.


## Overall idea:

Use [Nerves](https://nerves-project.org/) to set up a local server (avaliable
on your network) that streams something you'd like to watch (such as outside
traffic, your pets or whatever you'd like) via wifi.


## Hardware needed:

- [Raspberry Pi 3 and accessories, including mini SD
  card](http://www.microcenter.com/product/506089/Raspberry_Pi_3_Model_B_Complete_Starter_Kit_-_16_GB_Edition)
- [Raspberry Pi Camera Module
  V2](http://www.microcenter.com/product/465935/raspberry_pi_camera_module_v2)

Note: You can find the above anywhere, get it where you think is optimal. Try to support Microcenter though! :)


## Software needed:

I'm using a Mac, Erlang 20 and Elixir 1.6
Your miles may vary depending on your setup.

Look at the below, do it and come back when you are done:

- If you don't have Elixir on your computer, go to
https://elixir-lang.org/install.html

- If you don't have Nerves on your computer, go to
https://hexdocs.pm/nerves/installation.html


## Important Note:

I'm going to be using the `exact` commands as I'm using it on my machine. I'll
only omit keys/passwords. I find this to be one of the biggest pain points in
starting out something you don't know about. Namespace clashes, a typo
somewhere, ommitting things that are assumed to be known by everyone. For
changes, I will show the output of `git diff` as I think that's a great way to
see what actually was done. I'm not sure that's the best way of displaying
differences, but I like it and I'm going to try it here.


## Steps and tools:

We are going to use Nerves and incrementally add features to our device. In order:

- Setup a new project with Nerves

- Add and configure a basics package that saves us a lot of time by
  allowing remote updates to the Raspberry Pi (Rpi from now on) and configures
  the networking (wifi included) on the Rpi. This is the
  [`nerves_init_gadget`](https://github.com/nerves-project/nerves_init_gadget)
  package.

- Deploy the app and connect to it's BEAM node through another node (one on our
  machine).  This doesn't really set us toward our main goal, but I think it is
  a good way to learn more about OTP.

- Add and configure [Picam](https://github.com/electricshaman/picam). We will
  first take a picture and make sure things are working correctly.

- Add a server layer with [`Plug`](https://hexdocs.pm/plug/readme.html). We
  will leverage the
  [example](https://github.com/electricshaman/picam/tree/master/examples/picam_http)
  and add it to our project.


## Step - Setting up project

Go to a folder of choice in your machine and run:

``` bash
  mix nerves.new nerves_rpi3_wifi_picam
  cd nerves_rpi3_wifi_picam
```

Type `y` when prompted to fetch dependencies.


## Step - `nerves_init_gadget`

One thing that I had already setup before but can see how it may trip some
folks up is generating an authorized key to make it more secure to talk to our
Rpi over the network. So if you have not set that up yet, do it. This is what I
used to have mine setup:
https://help.github.com/articles/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent/

Then, follow the [installation
steps](https://github.com/nerves-project/nerves_init_gadget#installation-for-a-new-project)
from the readme. `:nerves_network` is a dependency here and we set both up
below. Here are the files changes and their diffs:

```
## mix.exs

diff --git a/mix.exs b/mix.exs
   defp deps(target) do
     [
-      {:nerves_runtime, "~> 0.4"}
+      {:nerves_runtime, "~> 0.4"},
+      {:nerves_init_gadget, "~> 0.3"}
     ] ++ system(target)
   end

## config/config.exs

diff --git a/config/config.exs b/config/config.exs
 config :shoehorn,
-  init: [:nerves_runtime],
+  init: [:nerves_runtime, :nerves_init_gadget],
   app: Mix.Project.config()[:app]

+config :logger, backends: [RingLogger]
+
+config :nerves_firmware_ssh,
+  authorized_keys: [
+    File.read!(Path.join(System.user_home!, ".ssh/id_rsa.pub"))
+  ]
+
+config :logger, backends: [RingLogger]
+
+config :nerves_rpi3_wifi_picam, interface: :wlan0, port: 4001
+
+config :nerves_init_gadget,
+  node_name: :target01,
+  mdns_domain: "nerves.local",
+  address_method: :dhcp,
+  ifname: "wlan0"
+
+key_mgmt = System.get_env("NERVES_NETWORK_KEY_MGMT") || "WPA-PSK"
+
+config :nerves_network, :default,
+  wlan0: [
+    ssid: System.get_env("NERVES_NETWORK_SSID"),
+    psk: System.get_env("NERVES_NETWORK_PSK"),
+    key_mgmt: String.to_atom(key_mgmt)
+  ],
+  eth0: [
+    ipv4_address_method: :dhcp
+  ]
```

We are about ready to burn the firmware on the mini SD card (SD card from now
on). Before doing so, flash the SD card. On my Mac, I went to `Disk Utility`,
selected the SD card on the left and clicked "Erase". Here are more details on
that: https://www.youtube.com/watch?v=UmIanMx1HDM

Get the SD card and (its converter) and insert it in the computer.

Now, we can run these commands in succession:

```
  export NERVES_NETWORK_SSID=ButlerKasey
  export NERVES_NETWORK_PSK=your_network_password
  export MIX_TARGET=rpi3
  mix deps.get
  mix firmware
```

Note:

- the `NERVES_NETWORK_SSID` is your wifi network name. In my case,
  `ButlerKasey`, my cat and dog. :)
- Make sure to replace the `your_network_password` with your password.

 If success, run:

```
  mix firmware.burn
```

It will ask you to confirm the SD card it found, type `y` and then my machine
also prompted me for my login password.

Once burned, eject the SD card, place it in the device and wait a couple of
minutes.

Now, we should be in a great spot, because we should be able to push changes to
the device remotely. No more physically burning the SD card. I personally find
this mind blowing, I hope you do too.

When we set up `nerves_init_gadget`, we also set a couple of options that are
going to be useful now: `node_name` and `mdns_domain`. These combined are used
for setting up the device on the network. Instead of using its ip, you can use
its name -> `target01@nerves.local`


## Making sure things are connected with OTP:

Open up the project and see which cookie it created for this specific project.
It will be in `rel/vm.args`. It will be different for your project.

```
# in the rel/vm.args file:

-setcookie 1N1T5csB6k6gHtX47aQX4eZL07xEDknMK0JmOi42q67rhMyxMguQsV02ST/lsjoj
```

Use that cookie and run the below in a separate terminal instance in your
computer. This will create a named node in the VM network and pass it the
cookie we need to connect to our target node.

```
  iex --name host@0.0.0.0 --cookie "1N1T5csB6k6gHtX47aQX4eZL07xEDknMK0JmOi42q67rhMyxMguQsV02ST/lsjoj"
```

You will get an IEx shell and you are in Elixir land. Now, we connect the nodes
by running the below inside the IEx shell:

```
  Interactive Elixir (1.6.0) - press Ctrl+C to exit (type h() ENTER for help)
  iex(host@0.0.0.0)1> Node.connect(:"target01@nerves.local")
  true
  iex(host@0.0.0.0)2> Node.list
  [:"target01@nerves.local"]
  iex(host@0.0.0.0)3> :rpc.call(:"target01@nerves.local", NervesRpi3WifiPicam, :hello, [])
  :world
```

Please note that the `rpc` function call was made on the host but it was
computed in the target!  We can be sure of that because our IEx session on the
host is a simple one, meaning it doesn't know about the `NervesRpi3WifiPicam`
project at all.

If you have an HDMI cable and a keyboard/mouse setup, do the connection
exercise above when connected to a monitor/tv. You will see that when you
connect to the target, you can do `Node.list` on the target and it will list
the `host` node. This is pretty awesome.


## Push changes to the device remotely:

Now that our target is online, we can push changes to the device remotely. Try
it. Edit the `NervesRpi3WifiPicam.hello/0` function in
`nerves_rpi3_wifi_picam/lib/nerves_rpi3_wifi_picam.ex` to return `"not world"`
and run the below:

```
  export NERVES_NETWORK_SSID=ButlerKasey && export NERVES_NETWORK_PSK=your_network_password && export MIX_TARGET=rpi3 && mix firmware && mix firmware.push nerves.local
```

The gotcha for me here was the argument of `mix firmware.push`, which in our
case is `nerves.local`. Not the full name.

Wait a little bit, go back to the connected IEx session and try
`Node.connect(:"target01@nerves.local")`. It will return true when you are
connected. To confirm your changes, and call

```
  :rpc.call(:"target01@nerves.local", NervesRpi3WifiPicam, :hello, [])
```

We should get `not world`. Try it.


## Use ssh to connect to the device:

We can also SSH into the device. Folks are working on doing this in a simpler way on the Nerves side, but here we see an alternative:
[link](https://elixirforum.com/t/connect-to-a-nerves-system-using-ssh/10723/4)

We can run:
```
  ssh -p 8989 target01@nerves.local
```

If prompted about authenticity, type `yes`. We have access to the Erlang shell. In order to get the Elixir shell, run:

```
  'Elixir.IEx':start().
```

One thing I found was to disconned the session I closed my terminal instance.
If I did not, I had issues pushing changes to the target as @ConnorRigby
mentioned I would.

So, this is a neat feature, but not quite necessary for my needs yet.

## Step - Picam

Now that we can push changes, lets integrate Picam [using a library in
Elixir](https://github.com/electricshaman/picam). The changes to our project are:

```
# mix.exs

diff --git a/mix.exs b/mix.exs
   defp deps(target) do
     [
       {:nerves_runtime, "~> 0.4"},
-      {:nerves_init_gadget, "~> 0.3"}
+      {:nerves_init_gadget, "~> 0.3"},
+      {:picam, "~> 0.2.0"}
     ] ++ system(target)
   end

# lib/nerves_rpi3_wifi_picam.ex

+  def take_and_read_picture() do
+    Picam.Camera.start_link
+
+    Picam.next_frame
+    |> Base.encode64()
+    |> IO.puts()
+  end
```

My goal here was to make sure Picam was working correctly. So, I wanted to take
a picture and see that it worked. Turns out that the best way of doing that is
a hack Connor Rigby told me about: We can take a picture with Picam, create a
base 64 string from it and and pipe that to `IO.puts()`. We can access that
through ssh, take the string and convert it to an image with
https://codebeautify.org/base64-to-image-converter#

Haha!

To make this work, do: Push new changes to the device, assert that the device
is up, ssh into it, start an IEx process and call the function we created:

```
  # Here is the flow
  ~ :> ssh -p 8989 target01@nerves.local
    Eshell V9.3  (abort with ^G)
    (target01@nerves.local)1> 'Elixir.IEx':start().
    <0.501.0>
    Interactive Elixir (1.6.0) - press Ctrl+C to exit (type h() ENTER for help)
    iex(target01@nerves.local)1> NervesRpi3WifiPicam.take_and_read_picture()
    .
    . long string here, copy it to your clipboard
    .
```

We now have a picture. Now that our camera works, we will start to work on
getting the camera to stream and displaying that on a browser. There is an
example on the [Picam
repo](https://github.com/electricshaman/picam/tree/master/examples/picam_http)
that shows exactly what to do. We will integrate those changes to our project.
As usual, we will go step by step, starting with integration a web layer to our
project.

## Step - Server layer using Cowboy and Plug

We will use [Cowboy](https://github.com/ninenines/cowboy) to create an HTTP
server and use [Plug](https://github.com/elixir-plug/plug) to connect and
interact with Cowboy.  There was a great article about Plug this last week:
https://www.pompecki.com/post/plugs-demystified/. To add Plug and Cowboy to our
system, do:

```
# mix.exs
diff --git a/mix.exs b/mix.exs
-      {:picam, "~> 0.2.0"}
+      {:picam, "~> 0.2.0"},
+      {:cowboy, "~> 1.0.0"},
+      {:plug, "~> 1.0"}
     ] ++ system(target)

# edit lib/nerves_rpi3_wifi_picam/application.ex
   def children(_target) do
     [
-      # Starts a worker by calling: NervesRpi3WifiPicam.Worker.start_link(arg)
-      # {NervesRpi3WifiPicam.Worker, arg},
+      Plug.Adapters.Cowboy.child_spec(scheme: :http, plug: NervesRpi3WifiPicam.Router, options: [port: 4001])
     ]
   end
 end

# create lib/router.ex

+defmodule NervesRpi3WifiPicam.Router do
+  use Plug.Router
+
+  plug :match
+  plug :dispatch
+
+  get "/" do
+    markup = """
+    <html>
+    <head>
+      <title>Picam Video Stream</title>
+    </head>
+    <body>
+      <p>Hi!</>
+    </body>
+    </html>
+    """
+    conn
+    |> put_resp_header("Content-Type", "text/html")
+    |> send_resp(200, markup)
+  end
+end
```

Deploy the changes to the device, make sure it is up and visit:
`http://nerves.local:4001/`. We should see `Hi` rendered back to us.

## Step - Picam streamer

Now that we have a working server, let's finish the exercise by adding the
streaming feature with Picam.  Again, we go back to the existing example in the
Picam repo (see above for link) and create the `Streamer` exactly as the
example has:

```
# edit lib/nerves_rpi3_wifi_picam/application.ex
# to start the Picam process

+    Picam.Camera.start_link
     opts = [strategy: :one_for_one, name: NervesRpi3WifiPicam.Supervisor]
     Supervisor.start_link(children(@target), opts)
   end

# edit lib/router.ex
# to forward requests to the streamer

     |> put_resp_header("Content-Type", "text/html")
     |> send_resp(200, markup)
   end
+
+  forward "/video.mjpg", to: NervesRpi3WifiPicam.Streamer
 end

# create streamer.exs

+defmodule NervesRpi3WifiPicam.Streamer do
+  @moduledoc """
+  Plug for streaming an image
+  """
+  import Plug.Conn
+
+  @behaviour Plug
+  @boundary "w58EW1cEpjzydSCq"
+
+  def init(opts), do: opts
+
+  def call(conn, _opts) do
+    conn
+    |> put_resp_header("Age", "0")
+    |> put_resp_header("Cache-Control", "no-cache, private")
+    |> put_resp_header("Pragma", "no-cache")
+    |> put_resp_header("Content-Type", "multipart/x-mixed-replace; boundary=#{@boundary}")
+    |> send_chunked(200)
+    |> send_pictures
+  end
+
+  defp send_pictures(conn) do
+    send_picture(conn)
+    send_pictures(conn)
+  end
+
+  defp send_picture(conn) do
+    jpg = Picam.next_frame
+    size = byte_size(jpg)
+    header = "------#{@boundary}\r\nContent-Type: image/jpeg\r\nContent-length: #{size}\r\n\r\n"
+    footer = "\r\n"
+    with {:ok, conn} <- chunk(conn, header),
+         {:ok, conn} <- chunk(conn, jpg),
+         {:ok, conn} <- chunk(conn, footer),
+      do: conn
+  end
+end

# edit lib/router.exs
# to put it all together, display the video
   <body>
-    <p>Hi!</>
+    <img src="video.mjpg" />
   </body>
```

Cool! Deploy... and verify the url! Neat right?


## General thoughts and thanks:
I'm sure there are many other ways of doing this exercise. This is just the way I did it.
This was a practical, step by step combination of my notes.

Here is an example of things I know so far that could be better:
- I don't have to set ENV variables every time I run a command. Once I had that
  command, that was all I ran. Ctrl+p in the terminal, was smooth.
- I don't like where the `Picam.Camera.start_link` call was made. I'm not sure
  where to put it. It works where it is at, but there must be a better way.

Special thanks to some folks from the Nerves community that spent some time
helping me these last few days (in no particular order):
- Connor Rigby - @ConnorRigby)
- Justin Schneck - @mobileoverlord
- Jeff Smith - @electricshaman
- Tim Mecklem - @tmecklem

Thanks for reading!

-- PD
